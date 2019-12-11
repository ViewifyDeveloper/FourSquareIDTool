//
//  Networking.swift
//  ViewifyFourSquareProjectOne
//
//  Created by Patrick Doyle on 8/6/19.
//  Copyright © 2019 Patrick Doyle. All rights reserved.
//

import Foundation
import MapKit
import SwiftyJSON

//Protocol to communicate data back with ViewControllers
protocol NetworkingDelegate: class
{
    func appendTableViewVenues(venue: Venue)
    
}

//Class to handle all networking
class Networking {
    
    var delegate: NetworkingDelegate
    //API app identifiers
    let CLIENT_ID = "OMLSM2ZUXNSMMMDNMUGRVJVMDCYYJ41NUCLDOCVT3QLLLJ1M"
    let CLIENT_SECRET = "AJ5ILVZLJQY2CRTKQY3XTRMOOCD2L54CD2CEOTHMMY2LNMCI"
    var nearbyLocationsQueried = false
    var autoCompleteVenuesQueried = false
    //API query settings (date and limit)
    var callLimit:Int = 3
    var apiVersion: String = "20180323"
    
    init(delegate: NetworkingDelegate) {
        self.delegate = delegate
    }
    
    //Send URL GET Request, return JSON response
    func sendGetRequest(_ url: URL, completion: @escaping (JSON?, Error?) -> Void) {
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request, completionHandler: { (data, response, error) in
            guard let data = data,                            // is there data
                let response = response as? HTTPURLResponse,  // is there HTTP response
                (200 ..< 300) ~= response.statusCode,         // is statusCode 2XX
                error == nil else {                           // is there no error
                    completion(nil, error)
                    return
            }
            
            //Convert response data into JSON and return
            let jsonSerialization = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let responseObject = JSON(arrayLiteral: jsonSerialization)
            completion(responseObject, nil)
            
        })
        task.resume()
        
    }
    
    func queryNearbyVenues(){
    //Query venues near the user's location

        //Prevent multiple queries from location manager
        if nearbyLocationsQueried{return}
        nearbyLocationsQueried = true

        //Configure API URL and parameters
        let urlComponents = NSURLComponents(string: "https://api.foursquare.com/v2/venues/explore")!
        urlComponents.queryItems = [
            URLQueryItem(name: "ll", value: currentLocationFormattedCoords),
            URLQueryItem(name: "client_id", value: CLIENT_ID),
            URLQueryItem(name: "client_secret", value: CLIENT_SECRET),
            URLQueryItem(name: "v", value: apiVersion),
            URLQueryItem(name: "limit", value: String(callLimit)),
        ]
        
        //Send GET Request to get API venue JSON data
        sendGetRequest(urlComponents.url!, completion: { responseObject, error in
            guard let nearbyVenuesJSON = responseObject, error == nil else {
                print(error ?? "Unknown error")
                return
            }
            
            //For each nearby venue, perform a second query to get venue details
            if let nearbyVenues = nearbyVenuesJSON[0]["response"]["groups"][0]["items"].array {
                for venue in nearbyVenues {
                    if let venueID = venue["venue"]["id"].string{
                        self.queryVenueDetailsAndPopulateTableView(venueID: venueID)
                    }
                }
            }
            
        })
        

    }
    
    func queryAutoCompleteVenues(autoCompleteString: String){
        //Query venue auto-complete names based on text entered in search bar
        
        //Configure API URL and parameters
        let urlComponents = NSURLComponents(string: "https://api.foursquare.com/v2/venues/suggestcompletion")!
        urlComponents.queryItems = [
            URLQueryItem(name: "ll", value: currentLocationFormattedCoords),
            URLQueryItem(name: "client_id", value: CLIENT_ID),
            URLQueryItem(name: "client_secret", value: CLIENT_SECRET),
            URLQueryItem(name: "v", value: apiVersion),
            URLQueryItem(name: "limit", value: String(callLimit)),
            URLQueryItem(name: "query", value: autoCompleteString),
        ]
        
         //Send GET Request to get API venue JSON data
        sendGetRequest(urlComponents.url!, completion: { responseObject, error in
            guard let suggestedVenuesJSON = responseObject, error == nil else {
                print(error ?? "Unknown error")
                return
            }
            
            //For each suggested venue, add the name to the TableView
            //Also store the ID so that the venue can be queried if an auto-complete cell is tapped
            if let suggestedVenues = suggestedVenuesJSON[0]["response"]["minivenues"].array {
                for venue in suggestedVenues {
                    if let venueName = venue["name"].string, let venueID = venue["id"].string{
                        let autoCompleteVenue = Venue()
                        autoCompleteVenue.name = venueName
                        autoCompleteVenue.id = venueID
                        self.delegate.appendTableViewVenues(venue: autoCompleteVenue)
                    }
                    
                }
            }
        })
        
    }
    
    func queryVenuesUsingSearch(venueName: String){
        //Query venues by using the API to search the venueName
        
        //Configure API URL and parameters
        let urlComponents = NSURLComponents(string: "https://api.foursquare.com/v2/venues/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "ll", value: currentLocationFormattedCoords),
            URLQueryItem(name: "client_id", value: CLIENT_ID),
            URLQueryItem(name: "client_secret", value: CLIENT_SECRET),
            URLQueryItem(name: "v", value: apiVersion),
            URLQueryItem(name: "limit", value: String(callLimit)),
            URLQueryItem(name: "query", value: venueName),
        ]
        
         //Send GET Request to get API venue JSON data
        sendGetRequest(urlComponents.url!, completion: { responseObject, error in
            guard let searchedVenuesJSON = responseObject, error == nil else {
                print(error ?? "Unknown error")
                return
            }
            
            //For each venue, perform a second query to get venue details
            if let searchedVenues = searchedVenuesJSON[0]["response"]["venues"].array {
                for venue in searchedVenues {
                    if let venueID = venue["id"].string{
                        self.queryVenueDetailsAndPopulateTableView(venueID: venueID)
                    }
                    
                }
            }
            
        })
        
    }
    
    
    func queryVenueDetailsAndPopulateTableView(venueID: String){
        //Query venues for details (address, categories, hours, price) and append the TableView with detailed venue
        
        //Configure API URL and parameters
        let venueDetailsURLString = "https://api.foursquare.com/v2/venues/" + venueID
        let urlComponents = NSURLComponents(string: venueDetailsURLString)!
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: CLIENT_ID),
            URLQueryItem(name: "client_secret", value: CLIENT_SECRET),
            URLQueryItem(name: "v", value: "20180323"),
        ]
        
        //Send GET Request to get API venue JSON data
        sendGetRequest(urlComponents.url!, completion: { responseObject, error in
            guard let venueDetailsJSON = responseObject, error == nil else {
                print(error?.localizedDescription ?? "Unknown error")
                return
            }
            
            //Initialize new venue
            var venueWithDetails = Venue()
            venueWithDetails.id = venueID
            //Parse JSON for venue details
            let venueDetails = venueDetailsJSON[0]["response"]["venue"]
            
            //Parse JSON for venue name.  If the venue name is missing, then return
            guard let venueName = venueDetails["name"].string else {return}
            venueWithDetails.name = venueName
            
            //Parse JSON for venue address.
            if let venueAddress = venueDetails["location"]["formattedAddress"].array{
                var address = ""
                var index = 0
                for addressLines in venueAddress {
                    if let addressLinesString = addressLines.string{
                        address += addressLinesString + ". "
                    }
                }
                venueWithDetails.address = address
            }
            
            //Parse JSON for venue categories
            if let venueCategories = venueDetails["categories"].array{
                var categories = ""
                for category in venueCategories {
                    if let categoryName = category["name"].string{
                        categories += categoryName + " \u{2022}"
                    }
                }
                venueWithDetails.category = categories
            }
            
            //Parse JSON for venue hours
            if let hoursTimeFrames = venueDetails["hours"]["timeframes"].array{
                var hours = ""
                for timeframe in hoursTimeFrames {
                    if let days = timeframe["days"].string{
                        hours += days + " "
                        if let openTimes = timeframe["open"].array{
                            for openTime in openTimes {
                                if let openTimeString = openTime["renderedTime"].string{
                                    hours += "Open: " + openTimeString + " "
                                }
                            }
                        }
                    }
                }
                venueWithDetails.hours = hours
            }
            
            //Parse JSON for venue price tier
            //For each tier, add another $ sign (i.e. Tier 3 = $$$)
            if let priceTier = venueDetails["price"]["tier"].int {
                var priceTierString = ""
                var i = 0
                while i < priceTier {
                    priceTierString += "$"
                    i += 1
                }
                venueWithDetails.price = priceTierString
            }
            
            self.delegate.appendTableViewVenues(venue: venueWithDetails)
            
            
        })
        
        
        
    }
    
    
    
    
    
}


