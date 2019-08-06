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

let locationManager = CLLocationManager()
var currentLocation: CLLocation?
var currentLocationFormattedCoords:String = ""//User's current location

class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate {
    
    
    @IBOutlet weak var venuesTableView: UITableView!
    @IBOutlet weak var searchBar: UITextField!
    
    
    enum TableViewMode {
        case defaultVenues
        case searchAutoComplete
        case searchedVenues
    }
    var currentTableViewMode: TableViewMode = .defaultVenues //Default table view mode starts as "Default Venues" when the app launches
    
    var defaultVenues: [DefaultVenue] = []
    var searchAutoComplete: [DefaultVenue] = []
    var searchedVenues: [DefaultVenue] = []
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Request location authorizations
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        
        //Set tableViewDelegates
        venuesTableView.delegate = self
        venuesTableView.dataSource = self
        
        //Get user's location and show default nearby venues
        getCurrentLocationAndNearbyVenues()
        
        
    }
    
    
    @IBAction func beginEditingSearchBar(_ sender: Any) {
        
        //When beginning a search, update the tableView mode and reload the tableview to clear data
        currentTableViewMode = .searchAutoComplete
        venuesTableView.reloadData()
        
    }
    
    @IBAction func searchBarTextChanged(_ sender: UITextField) {
        
        print(sender.text)
        guard let suggestSearchText = sender.text else {return}
        if suggestSearchText.count < 4 {return} //Suggest autoComplete API only works with at least 3 characters
        self.currentTableViewMode = .searchAutoComplete //Update currentTableViewMode so tableview shows correct datatype
        
        //Query for places using auto-complete API
        queryAutoCompleteVenues(autoCompleteString: suggestSearchText)
        
        
        
    }
    

    
    func getCurrentLocationAndNearbyVenues(){
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
      //  queryNearbyPlaces()
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
                        self.queryVenueDetailsAndPopulateTableView(venueID: venueID)
                    }
                   
                }
            }
            
            DispatchQueue.main.async {
                self.venuesTableView.reloadData()
            }
           
      
        })
        
        
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch currentTableViewMode{
        case .defaultVenues: return defaultVenues.count
        case .searchAutoComplete: return searchAutoComplete.count
        case .searchedVenues: return searchedVenues.count
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = venuesTableView.dequeueReusableCell(withIdentifier: "cellDefaultVenue", for: indexPath) as? DefaultVenueCell{
            
            //Get venue from appropriate list depending on tableView mode
            var venue = DefaultVenue()
            switch currentTableViewMode{
            case .defaultVenues: venue = defaultVenues[indexPath.row]
            case .searchAutoComplete: venue = searchAutoComplete[indexPath.row]
            case .searchedVenues: venue = searchedVenues[indexPath.row]
            }
            
            cell.venueName.text = venue.name
            cell.venueDetailsOne.text = venue.category + " - " + venue.price + " - " + venue.hours
            cell.venueDetailsTwo.text = venue.address
            
            print("RETURN GOOD CELL")
            
            return cell} else {
            print("RETURN BAD CELL")
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //Update the text in the search bar if a table view venue is tapped
        //If the venue clicked is an auto-complete venue, then perform a venue search using the venue name
        switch currentTableViewMode {
        case .defaultVenues: searchBar.text = defaultVenues[indexPath.row].name
        case .searchAutoComplete:
            let venueToSearch = searchAutoComplete[indexPath.row].name
            searchBar.text = venueToSearch
            currentTableViewMode = .searchedVenues //Update tableViewMode to "search"
            searchedVenues = [] //Clear searchedVenues array since new search is being queried
            venuesTableView.reloadData() //Reload/clear tableview so user knows that a search is being performed
            queryVenuesUsingSearch(venueName: venueToSearch) //Search for venue
            
        case .searchedVenues:
            searchBar.text = searchedVenues[indexPath.row].name
        }
    }
    
    func queryAutoCompleteVenues(autoCompleteString: String){
        
        if autoCompleteVenuesQueried {return}
        autoCompleteVenuesQueried = true
        
        print("QUERYING AUTO COMPLETE")
        
        var urlComponents = NSURLComponents(string: "https://api.foursquare.com/v2/venues/suggestcompletion")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "ll", value: currentLocationFormattedCoords),
            URLQueryItem(name: "client_id", value: CLIENT_ID),
            URLQueryItem(name: "client_secret", value: CLIENT_SECRET),
            URLQueryItem(name: "v", value: "20180323"),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "query", value: autoCompleteString),
        ]
        
        
        
        sendGetRequest(urlComponents.url!, completion: { responseObject, error in
            guard let suggestedVenuesJSON = responseObject, error == nil else {
                print(error ?? "Unknown error")
                return
            }
            
            print("AUTOCOMPLETE RECEIVED")
            print(suggestedVenuesJSON)
            if let suggestedVenues = suggestedVenuesJSON[0]["response"]["minivenues"].array {
                print("MiniVenuesCount", suggestedVenues.count)
                for venue in suggestedVenues {
                    if let venueName = venue["name"].string{
                        var autoCompleteVenue = DefaultVenue()
                        autoCompleteVenue.name = venueName
                        
                        self.searchAutoComplete.append(autoCompleteVenue)
                    }
                    
                }
            }
            
            DispatchQueue.main.async {
                self.venuesTableView.reloadData()
            }
            
            
        })
        
        
        
    }
    
    func queryVenuesUsingSearch(venueName: String){
        
        print("QUERYING SEARCH")
        
        var urlComponents = NSURLComponents(string: "https://api.foursquare.com/v2/venues/search")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "ll", value: currentLocationFormattedCoords),
            URLQueryItem(name: "client_id", value: CLIENT_ID),
            URLQueryItem(name: "client_secret", value: CLIENT_SECRET),
            URLQueryItem(name: "v", value: "20180323"),
            URLQueryItem(name: "limit", value: "2"),
            URLQueryItem(name: "query", value: venueName),
        ]
        
        
        
        sendGetRequest(urlComponents.url!, completion: { responseObject, error in
            guard let searchedVenuesJSON = responseObject, error == nil else {
                print(error ?? "Unknown error")
                return
            }
            
            print("SEARCH RECEIVED")
            print(searchedVenuesJSON)
            if let searchedVenues = searchedVenuesJSON[0]["response"]["venues"].array {
                print("SearchedVenuesCount", searchedVenues.count)
                for venue in searchedVenues {
                    if let venueID = venue["id"].string{
                       print("QUERYING DETAILS FOR SEARCH")
                        self.queryVenueDetailsAndPopulateTableView(venueID: venueID)
                    }
                    
                }
            }
            
            DispatchQueue.main.async {
                self.venuesTableView.reloadData()
            }
            
            
        })
        
    }
    
}

