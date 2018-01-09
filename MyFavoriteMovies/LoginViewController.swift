//
//  LoginViewController.swift
//  MyFavoriteMovies
//
//  Created by Jarrod Parkes on 1/23/15.
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - LoginViewController: UIViewController

class LoginViewController: UIViewController {
    
    // MARK: Properties
    
    var appDelegate: AppDelegate!
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: BorderedButton!
    @IBOutlet weak var debugTextLabel: UILabel!
    @IBOutlet weak var movieImageView: UIImageView!
        
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get the app delegate
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        configureUI()
        
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Login
    
    @IBAction func loginPressed(_ sender: AnyObject) {
        
        userDidTapView(self)
        
        if usernameTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
            debugTextLabel.text = "Username or Password Empty."
        } else {
            setUIEnabled(false)
            
            /*
                Steps for Authentication...
                https://www.themoviedb.org/documentation/api/sessions
                
                Step 1: Create a request token
                Step 2: Ask the user for permission via the API ("login")
                Step 3: Create a session ID
                
                Extra Steps...
                Step 4: Get the user id ;)
                Step 5: Go to the next view!            
            */
            getRequestToken()
        }
    }
    
    private func completeLogin() {
        performUIUpdatesOnMain {
            self.debugTextLabel.text = ""
            self.setUIEnabled(true)
            let controller = self.storyboard!.instantiateViewController(withIdentifier: "MoviesTabBarController") as! UITabBarController
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    // MARK: TheMovieDB
    
    private func getRequestToken() {
        
        /* TASK: Get a request token, then store it (appDelegate.requestToken) and login with the token */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/authentication/token/new"))
        
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) { (data, response, error) in
            
            func displayError(error: String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.debugTextLabel.text = "Login Failed (Request Token)"
                }
            
            }
            
            /* 5. Parse the data */
            guard error == nil else {
                displayError(error: "There is an error, \(error!)")
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError(error: "Your request was return a statusCode > 299.")
                return
            }
            
            guard let data = data else{
                displayError(error: "Your response was not include any data.")
                return
            }
            
            var parseResult = [String: AnyObject]()
            do {
                parseResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: AnyObject]
            }catch {
                displayError(error: "Could not parse the data as JSON: '\(data)'")
                return
            }
            
            
            /* 6. Use the data! */
            guard let requestToken = parseResult["request_token"] as? String else {
                displayError(error: "There was no request token in the respose data.")
                return
            }
            self.appDelegate.requestToken = requestToken
            print(requestToken)
            self.loginWithToken(requestToken)
        }

        /* 7. Start the request */
        task.resume()
    }
    
    private func loginWithToken(_ requestToken: String) {
        
        /* TASK: Login, then get a session id */
        
        /* 1. Set the parameters */
        let methodParameters = [Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey,
                                Constants.TMDBParameterKeys.RequestToken: requestToken,
                                Constants.TMDBParameterKeys.Username: usernameTextField.text!,
                                Constants.TMDBParameterKeys.Password: passwordTextField.text!]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String: AnyObject], withPathExtension: "/authentication/token/validate_with_login"))
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) {(data, response, error) in
            func displayError(error: String) {
                print("There is an error \(error) in the task.")
                performUIUpdatesOnMain {
                    self.debugTextLabel.text = "Logging error."
                    self.setUIEnabled(true)
                }
            }
            guard (error != nil) else {
                displayError(error: "There is an error in your request")
                return
            }
            
            guard let methodCode = (response as? HTTPURLResponse)?.statusCode, methodCode >= 200 && methodCode <= 299 else {
                displayError(error: "The methodCode is not 2XX")
                return
            }
            
            guard let data = data else {
                displayError(error: "There is no data by the request.")
                return
            }
            
            let parseResult: [String: AnyObject]
            do {
                parseResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: AnyObject]
            }catch {
                displayError(error: "Can not parse the data.")
                return
            }
            
            guard let _ = parseResult[Constants.TMDBResponseKeys.StatusCode] as? Int else{
                displayError(error: "TheMovieDB returned an error. See the \(Constants.TMDBResponseKeys.StatusCode) and \(Constants.TMDBResponseKeys.StatusMessage) in \(parseResult)")
                return
            }
            
            guard let success = parseResult[Constants.TMDBResponseKeys.Success] as? Bool, success == true else{
                displayError(error: "Can\'t find the key \(Constants.TMDBResponseKeys.Success) in the \(parseResult)")
                return
            }
            
        }
        /* 5. Parse the data */
        /* 6. Use the data! */
        print("Success")
        self.getSessionID(self.appDelegate.requestToken!)
    }
    
    private func getSessionID(_ requestToken: String) {
        
        /* TASK: Get a session ID, then store it (appDelegate.sessionID) and get the user's id */
        
        /* 1. Set the parameters */
        let methodParameters = [Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey,
                                Constants.TMDBParameterKeys.RequestToken: requestToken,
                                Constants.TMDBParameterKeys.Username: self.usernameTextField.text!,
                                Constants.TMDBParameterKeys.Password: self.passwordTextField.text!] as [String : Any]
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String: AnyObject], withPathExtension: "/authentication/session/new"))
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) {(data, response, error) in
            func displayError(error: String) {
                print(error)
                performUIUpdatesOnMain {
                    self.debugTextLabel.text = "Log failed (Get sessionID step)"
                    self.setUIEnabled(true)
                }
            }
            
            guard (error == nil) else{
                displayError(error: "There is an error by the request\(error).")
                return
            }
            
            guard let responseCode = (response as? HTTPURLResponse)?.statusCode, responseCode >= 200 && responseCode <= 299 else {
                displayError(error: "Your request returned an code is not 2XX.")
                return
            }
            
            guard let data = data else {
                displayError(error: "There is no data in the response.")
                return
            }
            
            let parseResult: [String: AnyObject]
            do {
                parseResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: AnyObject]
            }catch {
                displayError(error: "Can not parse the data.")
                return
            }
            
            if let _ = parseResult[Constants.TMDBResponseKeys.StatusCode] as? Int {
                displayError(error: "The TMDB returned an error. See the \(Constants.TMDBResponseKeys.StatusCode) and \(Constants.TMDBResponseKeys.StatusMessage) in \(parseResult)")
            }
            
            guard let sessionID = parseResult[Constants.TMDBResponseKeys.SessionID] as? String else {
                displayError(error: "Can not find \(Constants.TMDBResponseKeys.SessionID) in \(parseResult)")
                return
            }
            self.debugTextLabel.text = sessionID
            self.appDelegate.sessionID = sessionID
            self.getUserID(sessionID)
        }
        /* 5. Parse the data */
        /* 6. Use the data! */
        
        /* 7. Start the request */
        task.resume()
    }
    
    private func getUserID(_ sessionID: String) {
        
        /* TASK: Get the user's ID, then store it (appDelegate.userID) for future use and go to next view! */
        
        /* 1. Set the parameters */
        /* 2/3. Build the URL, Configure the request */
        /* 4. Make the request */
        /* 5. Parse the data */
        /* 6. Use the data! */
        /* 7. Start the request */
    }
}

// MARK: - LoginViewController: UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
            movieImageView.isHidden = true
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
            movieImageView.isHidden = false
        }
    }
    
    func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    private func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(usernameTextField)
        resignIfFirstResponder(passwordTextField)
    }
}

// MARK: - LoginViewController (Configure UI)

private extension LoginViewController {
    
    func setUIEnabled(_ enabled: Bool) {
        usernameTextField.isEnabled = enabled
        passwordTextField.isEnabled = enabled
        loginButton.isEnabled = enabled
        debugTextLabel.text = ""
        debugTextLabel.isEnabled = enabled
        
        // adjust login button alpha
        if enabled {
            loginButton.alpha = 1.0
        } else {
            loginButton.alpha = 0.5
        }
    }
    
    func configureUI() {
        
        // configure background gradient
        let backgroundGradient = CAGradientLayer()
        backgroundGradient.colors = [Constants.UI.LoginColorTop, Constants.UI.LoginColorBottom]
        backgroundGradient.locations = [0.0, 1.0]
        backgroundGradient.frame = view.frame
        view.layer.insertSublayer(backgroundGradient, at: 0)
        
        configureTextField(usernameTextField)
        configureTextField(passwordTextField)
    }
    
    func configureTextField(_ textField: UITextField) {
        let textFieldPaddingViewFrame = CGRect(x: 0.0, y: 0.0, width: 13.0, height: 0.0)
        let textFieldPaddingView = UIView(frame: textFieldPaddingViewFrame)
        textField.leftView = textFieldPaddingView
        textField.leftViewMode = .always
        textField.backgroundColor = Constants.UI.GreyColor
        textField.textColor = Constants.UI.BlueColor
        textField.attributedPlaceholder = NSAttributedString(string: textField.placeholder!, attributes: [NSForegroundColorAttributeName: UIColor.white])
        textField.tintColor = Constants.UI.BlueColor
        textField.delegate = self
    }
}

// MARK: - LoginViewController (Notifications)

private extension LoginViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
