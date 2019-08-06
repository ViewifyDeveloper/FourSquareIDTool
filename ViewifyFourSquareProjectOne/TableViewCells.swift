//
//  TableViewCells.swift
//  ViewifyFourSquareProjectOne
//
//  Created by Patrick Doyle on 8/6/19.
//  Copyright © 2019 Patrick Doyle. All rights reserved.
//

import Foundation
import UIKit

//Custom cell for venues tableView
class VenueCell: UITableViewCell {
    
    @IBOutlet weak var venueName: UILabel!
    @IBOutlet weak var venueDetailsOne: UILabel!
    @IBOutlet weak var venueDetailsTwo: UILabel!
    
    @IBOutlet weak var venueDetailsThree: UILabel!
    
}

class SearchAutoCompleteCell: UITableViewCell {
    
    @IBOutlet weak var venueName: UILabel!
    
}
