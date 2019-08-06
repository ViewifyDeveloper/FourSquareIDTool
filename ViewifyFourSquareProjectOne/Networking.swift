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


let CLIENT_ID = "OMLSM2ZUXNSMMMDNMUGRVJVMDCYYJ41NUCLDOCVT3QLLLJ1M"
let CLIENT_SECRET = "AJ5ILVZLJQY2CRTKQY3XTRMOOCD2L54CD2CEOTHMMY2LNMCI"
var nearbyLocationsQueried = false
var autoCompleteVenuesQueried = false

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

func queryNearbyPlaces(){
    
    if nearbyLocationsQueried{return}
    
    nearbyLocationsQueried = true
    //do HTTP GET to get the user's current venue
    
    var urlComponents = NSURLComponents(string: "https://api.foursquare.com/v2/venues/explore")!
    
    urlComponents.queryItems = [
        URLQueryItem(name: "ll", value: currentLocationFormattedCoords),
        URLQueryItem(name: "client_id", value: CLIENT_ID),
        URLQueryItem(name: "client_secret", value: CLIENT_SECRET),
        URLQueryItem(name: "v", value: "20180323"),
        URLQueryItem(name: "limit", value: "1"),
    ]
    
    
    
    sendGetRequest(urlComponents.url!, completion: { responseObject, error in
        guard let nearbyVenuesJSON = responseObject, error == nil else {
            print(error ?? "Unknown error")
            return
        }
        
        //print(nearbyVenuesJSON.description)
        if let recommendedVenues = nearbyVenuesJSON[0]["response"]["groups"][0]["items"].array {
            print("VenuesCount", recommendedVenues.count)
            for venue in recommendedVenues {
                print(venue["venue"]["id"].string)
                if let venueID = venue["venue"]["id"].string{
                    queryVenueDetailsAndPopulateTableView(venueID: venueID)
                }
                
            }
        }
        
        
        
    })
    
    func queryVenueDetailsAndPopulateTableView(venueID: String){
        
        
        //do HTTP GET to get the user's current venue
        let venueDetailsURLString = "https://api.foursquare.com/v2/venues/" + venueID
        var urlComponents = NSURLComponents(string: venueDetailsURLString)!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: CLIENT_ID),
            URLQueryItem(name: "client_secret", value: CLIENT_SECRET),
            URLQueryItem(name: "v", value: "20180323"),
        ]
        
        
        
        sendGetRequest(urlComponents.url!, completion: { responseObject, error in
            guard let venueDetailsJSON = responseObject, error == nil else {
                print(error?.localizedDescription ?? "Unknown error")
                return
            }
            
            //Initialize new default venue
            var venueWithDetails = DefaultVenue()
            
            //Get venue details
            let venueDetails = venueDetailsJSON[0]["response"]["venue"]
            
            //Get the venue name.  If the venue is missing a name, then return
            guard let venueName = venueDetails["name"].string else {return}
            venueWithDetails.name = venueName
            
            //Add venue address to venue
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
            
            //Add categories to venue
            if let venueCategories = venueDetails["categories"].array{
                var categories = ""
                for category in venueCategories {
                    if let categoryName = category["name"].string{
                        categories += categoryName + " "
                    }
                }
                venueWithDetails.category = categories
            }
            
            //Add hours to venue
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
            
            //Add price to venue
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
            
            //Add venue to the appropriate list of venues depending on app mode
            switch self.currentTableViewMode{
            case .defaultVenues: self.defaultVenues.append(venueWithDetails)
            case .searchAutoComplete: self.searchAutoComplete.append(venueWithDetails)
            case .searchedVenues: self.searchedVenues.append(venueWithDetails)
            }
            
            DispatchQueue.main.async {
                self.venuesTableView.reloadData()
            }
            
            print("DEFAULT VENUES COUNT", self.defaultVenues.count)
            print("VENUE NAME", venueWithDetails.name)
            print("VENUE ADDRESS", venueWithDetails.address)
            print("VENUE CATEGORY", venueWithDetails.category)
            print("VENUE PRICE", venueWithDetails.price)
            print("VENUE HOURS", venueWithDetails.hours)
            
        })
        
        
        
    }
    
    
    
}
