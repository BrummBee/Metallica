//
//  ViewController.swift
//  Metalldetektor
//
//  Created by Lukas Bühler on 05.10.16.
//  Copyright © 2016 Lukas Bühler. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {
    // Hier wird der locationManager importiert
    let locationManager = CLLocationManager()
    let viewController = UIViewController.self
    
    //UI Material:
    @IBOutlet weak var strengthLabel: UILabel!
    @IBOutlet weak var strengthProgressBar: UIProgressView!
    // Vector stuff:
    @IBOutlet weak var vectorXLabel: UILabel!
    @IBOutlet weak var vectorYLabel: UILabel!
    @IBOutlet weak var vectorZLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.delegate = self

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        locationManager.startUpdatingHeading()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: .UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: .UIApplicationWillResignActive, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        locationManager.stopUpdatingHeading()
        
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillResignActive, object: nil)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        locationManager.startUpdatingHeading()
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        locationManager.stopUpdatingHeading()
    }

    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading)
    {
        let x = newHeading.x
        let y = newHeading.y
        let z = newHeading.z
        
        let roundedX = round(x * 1000) / 1000
        let roundedY = round(y * 1000) / 1000
        let roundedZ = round(z * 1000) / 1000
        
        
        // magnitude = sqrt( x^2 + y^2 + z^2 )
        let magnitude = sqrt(x*x + y*y + z*z)
        let maxMagnitude = 1000.0 // the .0 part makes it a double instead of an int, so no conversion is needed
        let magnitudeRatio = magnitude / maxMagnitude
        
        // Upddate text and progressView
        strengthLabel.text = String(magnitude)
        strengthProgressBar.progress = Float(magnitudeRatio)
        
        vectorXLabel.text = String(roundedX)
        vectorYLabel.text = String(roundedY)
        vectorZLabel.text = String(roundedZ)
    }
    
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let errorCode = (error as NSError).code
        if errorCode == CLError.denied.rawValue {
            manager.stopUpdatingHeading()
        } else if errorCode == CLError.headingFailure.rawValue {
            print("error heading failure")
        }
    }
    
    @IBAction func logQRPressed(_ sender: AnyObject) {
        
        var json = [String: Any]()
        json["task"] = "Metalldetektor"
        
        let solutionLogger = SolutionLogger(viewController: self)
        solutionLogger.scanQRCode { code in
            // Show alert to confirm your log
            let alertController = UIAlertController(title: "Do you want to log?", message: "Code: \"\(code)\"", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Log!", style: .default, handler: {(action:UIAlertAction) in
                // Go ahead to submit:
                json["solution"] = code
                let solutionStr = SolutionLogger.JSONStringify(json)
                solutionLogger.logSolution(solutionStr)
                
            }))
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            
            
        }
    }
}

