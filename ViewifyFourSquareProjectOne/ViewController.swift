//
//  ViewController.swift
//  ViewifyFourSquareProjectOne
//
//  Created by Patrick Doyle on 8/5/19.
//  Copyright © 2019 Patrick Doyle. All rights reserved.
//

import UIKit
import MapKit
import SwiftyJSON

class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate {
    
    
    @IBOutlet weak var venuesTableView: UITableView!
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return defaultVenues.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = venuesTableView.dequeueReusableCell(withIdentifier: "cellDefaultVenue", for: indexPath) as? DefaultVenueCell{
            
            
            
            return cell}
        return UITableViewCell()
    }
    
    

    
    let CLIENT_ID = "C03BBSQZK3QU10R140T3ADB1KDBKVD3BONRKR0STBGLX2VRI"
    let CLIENT_SECRET = "O0GGI2JYXDEPCDPQ1143XBFUGGZVYOUNZ3MK343IMC5NIODW"
    let locationManager = CLLocationManager()
    var currentLocation: CLLocation?
    var currentLocationFormattedCoords:String = ""//User's current location
    var nearbyLocationsQueried = false
    
    var defaultVenues: [DefaultVenue] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // Request location authorizations
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        
        getCurrentLocation()
        
       
        
    }
    
    func sendRequest(_ url: URL, completion: @escaping (JSON?, Error?) -> Void) {
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request, completionHandler: { (data, response, error) in
            guard let data = data,                            // is there data
                let response = response as? HTTPURLResponse,  // is there HTTP response
                (200 ..< 300) ~= response.statusCode,         // is statusCode 2XX
                error == nil else {                           // was there no error, otherwise ...
                    completion(nil, error)
                    return
            }
           // print("RESPONSE1", data)
           // let responseObject = (try? JSON(data: data))
            let jsonSerialization = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let responseObject = JSON(arrayLiteral: jsonSerialization)
            completion(responseObject, nil)
            
            
        })
        task.resume()
        
    }
    
    func getCurrentLocation(){
        if currentLocation == nil {
            //Get user's current location
            DispatchQueue.global(qos: .userInteractive).async {
                if CLLocationManager.locationServicesEnabled() {
                    self.locationManager.delegate = self
                    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                    self.locationManager.startUpdatingLocation()
                }
            }
        } else {
           // currentLocationRetrieved()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations{
            currentLocation = location
        }
        print("COORDINATES")
        print(currentLocation?.coordinate)
        guard let currentLocation = currentLocation else {return}
        currentLocationFormattedCoords = String(Double(currentLocation.coordinate.latitude)) + "," + String(Double(currentLocation.coordinate.longitude))
        print("Formatted Coords")
        print(currentLocationFormattedCoords)
        queryNearbyPlaces()
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
        ]
        
        
        
        sendRequest(urlComponents.url!, completion: { responseObject, error in
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
                        self.queryVenueDetails(venueID: venueID)
                    }
                   
                }
            }
           
      
        })
        
        
        
    }
    
    func queryVenueDetails(venueID: String){
        
 
        //do HTTP GET to get the user's current venue
        let venueDetailsURLString = "https://api.foursquare.com/v2/venues/" + venueID
        var urlComponents = NSURLComponents(string: venueDetailsURLString)!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: CLIENT_ID),
            URLQueryItem(name: "client_secret", value: CLIENT_SECRET),
            URLQueryItem(name: "v", value: "20180323"),
        ]
        
        
        
        sendRequest(urlComponents.url!, completion: { responseObject, error in
            guard let venueDetailsJSON = responseObject, error == nil else {
                print(error ?? "Unknown error")
                return
            }
            
            //Initialize new default venue
            var nearbyVenue = DefaultVenue()
            
            //Get venue details
            let venueDetails = venueDetailsJSON[0]["response"]["venue"]
            
            //Get the venue name.  If the venue is missing a name, then return
            guard let venueName = venueDetails["name"].string else {return}
            nearbyVenue.name = venueName
            
            //Add venue address to venue
            if let venueAddress = venueDetails["location"]["formattedAddress"].array{
                var address = ""
                for addressLines in venueAddress {
                    if let addressLinesString = addressLines.string{
                        address += addressLinesString + ". "
                    }
                }
                nearbyVenue.address = address
            }
            
            //Add categories to venue
            if let venueCategories = venueDetails["categories"].array{
                var categories = ""
                for category in venueCategories {
                    if let categoryName = category["name"].string{
                        categories += categoryName + " "
                    }
                }
                nearbyVenue.category = categories
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
                                    hours += "Open: " + openTimeString
                                }
                            }
                        }
                    }
                    
                }
                nearbyVenue.hours = hours
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
                nearbyVenue.price = priceTierString
            }
            
            //Add venue to list of default venues
            self.defaultVenues.append(nearbyVenue)
            
            print("DEFAULT VENUES COUNT", self.defaultVenues.count)
            
        })
        
        
        
    }
    
}

