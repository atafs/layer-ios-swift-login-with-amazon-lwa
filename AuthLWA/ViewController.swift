//
//  ViewController.swift
//  AuthLWA with AWSMobileClient using Federated Identities
//
//  Created by Hills, Dennis on 4/26/19.
//  Copyright © 2019 Hills, Dennis. All rights reserved.
//
//  Requires LoginWithAmazonProxy via Gist here: https://gist.github.com/mobilequickie/56916503a41ebb2374fea241ede26eab
//  This gist: https://gist.github.com/mobilequickie/47a238e073043a271425f7ffe9d56d5e
//
import UIKit
import LoginWithAmazon
import AWSMobileClient 

class ViewController: UIViewController, AIAuthenticationDelegate {
    
    @IBOutlet weak var btnLWALogin: UIButton!
    @IBOutlet weak var btnLWALogout: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initializeAWSMobileClient() //#2
    }
    
    // #3 Initializing the AWSMobileClient and take action based on current user state
    func initializeAWSMobileClient() {
        AWSMobileClient.sharedInstance().initialize { (userState, error) in
            
            if let userState = userState {
                switch(userState){
                case .signedIn: // is Signed IN
                    print("Logged In")
                    print("Cognito Identity Id (authenticated): \(String(describing: AWSMobileClient.sharedInstance().identityId))")
                case .signedOut: // is Signed OUT
                    print("Logged Out")
                    print("Cognito Identity Id (unauthenticated): \(String(describing: AWSMobileClient.sharedInstance().identityId))")
                case .signedOutUserPoolsTokenInvalid: // User Pools refresh token INVALID
                    print("User Pools refresh token is invalid or expired.")
                case .signedOutFederatedTokensInvalid: // e.g. Facebook, Google, or Login with Amazon refresh token is INVALID
                    print("Federated refresh token is invalid or expired.")
                default:
                    AWSMobileClient.sharedInstance().signOut()
                }
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    // User taps [Login with Amazon] button
    @IBAction func onClickLWALogin(_ sender: Any) {
        LoginWithAmazonProxy.sharedInstance.login(delegate: self)
    }
    
    // User taps [Logout]
    @IBAction func onClickLWALogout(_ sender: Any) {
        AMZNAuthorizationManager.shared().signOut { (error) in
            if((error) != nil) {
                print("error signing out: \(String(describing: error))")
            } else {
                print("Logout successfully!")
                DispatchQueue.main.async(execute: { () -> Void in
                    self.btnLWALogin.isEnabled = true
                    self.btnLWALogout.isEnabled = false
                })
            }
        }
    }
    
    // Login with Amazon - Successful login callback
    func requestDidSucceed(_ apiResult: APIResult!) {
        
        switch (apiResult.api) {
            
        case API.authorizeUser:
            LoginWithAmazonProxy.sharedInstance.getAccessToken(delegate: self)
            
        case API.getAccessToken:
            guard let LWAtoken = apiResult.result as? String else { return }
            print("LWA Access Token: \(LWAtoken)")
            
            // Get the user profile from LWA (OPTIONAL)
            LoginWithAmazonProxy.sharedInstance.getUserProfile(delegate: self)
            
            // #4
            // To federate Login with Amazon (LWA) as a sign-in provider, pass tokens to AWSMobileClient.sharedInstance().federatedSignIn() as part of Cognito Federated Identity Pool
            AWSMobileClient.sharedInstance().federatedSignIn(providerName: IdentityProvider.amazon.rawValue, token: LWAtoken ) { (userState, err) in
                if let error = err {
                    print("Federated sign in failed for LWA: \(error.localizedDescription)")
                }
                else
                {
                    print("Federated sign in succeeded for LWA: \(err?.localizedDescription ?? "No Error")");
                    DispatchQueue.main.async {
                        
                        // The getIdentityId() method will asynchronously fetch the identityId for the given logins map.
                        // It returns an object of type AWSTask<String> which on completion will contain the identityId or
                        // an error.
                        AWSMobileClient.sharedInstance().getIdentityId().continueWith { task in
                            if let error = task.error {
                                print("Error: \(error.localizedDescription) \((error as NSError).userInfo)")
                            }
                            if let result = task.result {
                                print("Cognito Identity Id (authenticated via LWA): \(result)")
                            }
                            return nil
                        }
                    }
                }
            }
            
        case API.getProfile:
            print("LWA User Profile: \(String(describing: apiResult.result))")
            
        case API.clearAuthorizationState:
            print("user logged out from LWA")
            
            // Sign out from AWSMobileClient
            AWSMobileClient.sharedInstance().signOut()
            
        default:
            print("unsupported")
        }
    }
    
    // The login request to LWA failed
    func requestDidFail(_ errorResponse: APIError!) {
        print("Error: \(errorResponse.error.message ?? "nil")")
    }
}
