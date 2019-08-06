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

var currentLocation: CLLocation?
var currentLocationFormattedCoords:String = ""//User's current location

class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate, NetworkingDelegate {
    
    @IBOutlet weak var venuesTableView: UITableView!
    @IBOutlet weak var searchBar: UITextField!
    let locationManager = CLLocationManager()
    var networking:Networking?
    
    
    enum TableViewMode {
        case defaultVenues
        case searchAutoComplete
        case searchedVenues
    }
    var currentTableViewMode: TableViewMode = .defaultVenues //Default table view mode starts as "Default Venues" when the app launches
    
    var defaultVenues: [Venue] = []
    var searchAutoComplete: [Venue] = []
    var searchedVenues: [Venue] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        //Request location authorizations
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        
        //Set tableViewDelegates
        venuesTableView.delegate = self
        venuesTableView.dataSource = self
        
        //Set up networking class
        networking = Networking(delegate: self)
        
        //Get user's location and show default nearby venues
        getCurrentLocationAndNearbyVenues()
        
        
    }
    
    
    @IBAction func beginEditingSearchBar(_ sender: Any) {
        
        //When beginning a search, update the tableView mode and reload the tableview to clear data
        currentTableViewMode = .searchAutoComplete
        venuesTableView.reloadData()
        
    }
    
    @IBAction func searchBarTextChanged(_ sender: UITextField) {
        
        //When the user enters text in search bar, perform suggested auto-complete query
        //If the text is less than 4 characters, do not perform a query because API does not support small String lengths
        
        //Get user entered text
        guard let suggestSearchText = sender.text else {return}
        //If text is too short, clear tableview and return
        if suggestSearchText.count < 4 {
            searchedVenues = []
            venuesTableView.reloadData()
            return}
        
        //If text is long enough, update app mode to "AutoComplete" and peform suggested auto-complete query
        self.currentTableViewMode = .searchAutoComplete
        networking?.queryAutoCompleteVenues(autoCompleteString: suggestSearchText)
        
    }
    
    //Retrieve user's current location
    func getCurrentLocationAndNearbyVenues(){
        if currentLocation == nil {
            DispatchQueue.global(qos: .userInteractive).async {
                if CLLocationManager.locationServicesEnabled() {
                    self.locationManager.delegate = self
                    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                    self.locationManager.startUpdatingLocation()
                }
            }
        }
    }
    
    //User's current location retrieved
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //Update current location and formatted coordinates for API queries
        for location in locations{
            currentLocation = location
        }
        guard let currentLocation = currentLocation else {return}
        currentLocationFormattedCoords = String(Double(currentLocation.coordinate.latitude)) + "," + String(Double(currentLocation.coordinate.longitude))
  
        //Query nearby venues as soon as location is found
        networking?.queryNearbyVenues()
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
            var venue = Venue()
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
            networking?.queryVenuesUsingSearch(venueName: venueToSearch) //Search for venue
            
        case .searchedVenues:
            searchBar.text = searchedVenues[indexPath.row].name
        }
    }
    
    //Callback from networking class when TableView data needs to be appended
    func appendTableViewVenues(venue: Venue) {
        
        //Depending on app mode, add venue to appropriate array
        switch self.currentTableViewMode{
        case .defaultVenues: self.defaultVenues.append(venue)
        case .searchAutoComplete: self.searchAutoComplete.append(venue)
        case .searchedVenues: self.searchedVenues.append(venue)
        }
        
        //Reload tableView to display new data
        DispatchQueue.main.async {
            self.venuesTableView.reloadData()
        }
    }
    
    
}

