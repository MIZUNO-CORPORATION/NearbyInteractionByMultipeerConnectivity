//
//  ViewController.swift
//  NearbyInteractionByMultipeerConnectivity
//
//  Created by AM2190 on 2021/11/17.
//

import UIKit
import MultipeerConnectivity
import NearbyInteraction

class ViewController: UIViewController {
    // MARK: - NearbyInteraction variables
    var niSession: NISession?
    var myTokenData: Data?
    
    // MARK: - MultipeerConnectivity variables
    var mcSession: MCSession?
    var mcAdvertiser: MCNearbyServiceAdvertiser?
    var mcBrowserViewController: MCBrowserViewController?
    let mcServiceType = "mizuno-uwb"
    let mcPeerID = MCPeerID(displayName: UIDevice.current.name)
    
    // MARK: - CSV File instances
    var file: File!
    
    // MARK: - IBOutlet instances
    @IBOutlet weak var connectedDeviceNameLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var directionXLabel: UILabel!
    @IBOutlet weak var directionYLabel: UILabel!
    @IBOutlet weak var directionZLabel: UILabel!
    
    // MARK: - UI lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if niSession != nil {
            return
        }
        setupNearbyInteraction()
        setupMultipeerConnectivity()
        
        file = File.shared
    }
    
    // MARK: - Initial setting
    func setupNearbyInteraction() {
        // Check if Nearby Interaction is supported.
        guard NISession.isSupported else {
            print("This device doesn't support Nearby Interaction.")
            return
        }
        
        // Set the NISession.
        niSession = NISession()
        niSession?.delegate = self
        
        // Create a token and change Data type.
        guard let token = niSession?.discoveryToken else {
            return
        }
        myTokenData = try! NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }
    
    func setupMultipeerConnectivity() {
        // Set the MCSession for the advertiser.
        mcAdvertiser = MCNearbyServiceAdvertiser(peer: mcPeerID, discoveryInfo: nil, serviceType: mcServiceType)
        mcAdvertiser?.delegate = self
        mcAdvertiser?.startAdvertisingPeer()
        
        // Set the MCSession for the browser.
        mcSession = MCSession(peer: mcPeerID)
        mcSession?.delegate = self
        mcBrowserViewController = MCBrowserViewController(serviceType: mcServiceType, session: mcSession!)
        mcBrowserViewController?.delegate = self
        present(mcBrowserViewController!, animated: true)
    }
}

// MARK: - NISessionDelegate
extension ViewController: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        var stringData = ""
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }

        if let distance = accessory.distance {
            distanceLabel.text = distance.description
            stringData += distance.description
        }else {
            distanceLabel.text = "-"
        }
        stringData += ","
        
        
        if let direction = accessory.direction {
            directionXLabel.text = direction.x.description
            directionYLabel.text = direction.y.description
            directionZLabel.text = direction.z.description
            
            stringData += direction.x.description + ","
            stringData += direction.y.description + ","
            stringData += direction.z.description
        }else {
            directionXLabel.text = "-"
            directionYLabel.text = "-"
            directionZLabel.text = "-"
        }
        
        stringData += "\n"
        file.addDataToFile(rowString: stringData)
    }
    
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension ViewController: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, mcSession)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    }
}

// MARK: - MCSessionDelegate
extension ViewController: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            
            do {
                try session.send(myTokenData!, toPeers: session.connectedPeers, with: .reliable)

            } catch {
                print(error.localizedDescription)
            }
            
            DispatchQueue.main.async {
                self.mcBrowserViewController?.dismiss(animated: true, completion: nil)
                self.connectedDeviceNameLabel.text = peerID.displayName
            }
            
        default:
            print("MCSession state is \(state)")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        guard let peerDiscoverToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
            print("Failed to decode data.")
            return }
        
        let config = NINearbyPeerConfiguration(peerToken: peerDiscoverToken)
        niSession?.run(config)
        
        file.createFile(connectedDeviceName: peerID.displayName)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    }
}

// MARK: - MCBrowserViewControllerDelegate
extension ViewController: MCBrowserViewControllerDelegate {
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
    }
    
    func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
        return true
    }
}
