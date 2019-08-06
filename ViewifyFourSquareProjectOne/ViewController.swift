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
    
    //TableView can display 3 main types of data, nearby venues, auto-complete data, searched venues
    enum TableViewMode {
        case nearby
        case autoComplete
        case search
    }
    
    //Default table view mode starts as "nearby venues" when the app launches
    var currentTableViewMode: TableViewMode = .nearby
    
    var nearbyVenues: [Venue] = []
    var autoCompleteVenues: [Venue] = []
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
        currentTableViewMode = .autoComplete
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
        
        //Clear list of autoComplete venues when text is changed so that duplicate data does not appear
        autoCompleteVenues = []
        
        //If text is long enough, update app mode to "AutoComplete" and peform suggested auto-complete query
        self.currentTableViewMode = .autoComplete
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
        case .nearby: return nearbyVenues.count
        case .autoComplete: return autoCompleteVenues.count
        case .search: return searchedVenues.count
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        //Return appropriate tableView cell type depending on data being displayed
        //"Nearby" and "Search" mode both show full venue details
        //"Autocomplete" mode only shows venue name
        
        switch currentTableViewMode {
        case .autoComplete:
            let venue = autoCompleteVenues[indexPath.row]
            return configureBasicSingleNameCell(venue: venue, indexPath: indexPath)
        case .nearby:
             let venue = nearbyVenues[indexPath.row]
             return configureDetailedVenueCell(venue: venue, indexPath: indexPath)
        case .search:
            let venue = searchedVenues[indexPath.row]
            return configureDetailedVenueCell(venue: venue, indexPath: indexPath)
        }
        
        
    }
    
    func configureBasicSingleNameCell(venue: Venue, indexPath: IndexPath) -> SearchAutoCompleteCell{
        //Configure cell with only venue name
        if let cell = venuesTableView.dequeueReusableCell(withIdentifier: "cellSearchAutoComplete", for: indexPath) as? SearchAutoCompleteCell{
           
            cell.venueName.text = venue.name
            
            return cell
            
        } else {
            return SearchAutoCompleteCell()
        }
    }
    
    func configureDetailedVenueCell(venue: Venue, indexPath: IndexPath) -> VenueCell {
        //Configure cell with full Venue Details
        if let cell = venuesTableView.dequeueReusableCell(withIdentifier: "cellDefaultVenue", for: indexPath) as? VenueCell{
            
            cell.venueName.text = venue.name
            var firstSubString = ""
            if venue.price != "" {
                firstSubString += venue.price
            }
            if venue.category != "" {
                if venue.price != "" {
                    firstSubString += " \u{2022} " + venue.category
                } else {
                    firstSubString += venue.category
                }
            }
            cell.venueDetailsOne.text = firstSubString
            cell.venueDetailsTwo.text = venue.hours
            cell.venueDetailsThree.text = venue.address
            
            return cell
        } else {
            return VenueCell()
        }
    }
    
    //TableView item tapped
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //Update the text in the search bar if a table view venue is tapped
        //If the venue clicked is an auto-complete venue, then perform a venue search using the venue name
        switch currentTableViewMode {
        case .nearby: searchBar.text = nearbyVenues[indexPath.row].name
        case .autoComplete:
            let venueToSearch = autoCompleteVenues[indexPath.row].name
            searchBar.text = venueToSearch
            currentTableViewMode = .search //Update tableViewMode to "search"
            searchedVenues = [] //Clear searchedVenues array since new search is being queried
            venuesTableView.reloadData() //Reload/clear tableview so user knows that a search is being performed
            networking?.queryVenuesUsingSearch(venueName: venueToSearch) //Search for venue
        case .search:
            searchBar.text = searchedVenues[indexPath.row].name
        }
    }
    
    //Callback from networking class when TableView data needs to be appended
    func appendTableViewVenues(venue: Venue) {
        
        //Depending on app mode, add venue to appropriate array
        switch self.currentTableViewMode{
        case .nearby: self.nearbyVenues.append(venue)
        case .autoComplete: self.autoCompleteVenues.append(venue)
        case .search: self.searchedVenues.append(venue)
        }
        
        //Reload tableView to display new data
        DispatchQueue.main.async {
            self.venuesTableView.reloadData()
        }
    }
    
    
}

