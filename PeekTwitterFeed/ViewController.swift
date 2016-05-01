//
//  ViewController.swift
//  PeekTwitterFeed
//
//  Created by Michael Milholen on 4/30/16.
//  Copyright © 2016 Michael Milholen. All rights reserved.
//

import UIKit
import TwitterKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - UI Elements
    @IBOutlet weak var tableView: UITableView!
    
    var client: TWTRAPIClient!
    var tweets = [TWTRTweet]()
    
    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        authenticate {
            self.fetchTweets()
        }
    }
    
    private func authenticate(completion: (() -> Void)?) {
        weak var weakSelf = self
        Twitter.sharedInstance().logInWithCompletion { session, error in
            if let s = session, c = completion {
                weakSelf?.client = TWTRAPIClient(userID: s.userID)
                c()
            } else if let e = error {
                print("error: \(e.localizedDescription)");
            }
        }
    }
    
    private func fetchTweets() {
        weak var weakSelf = self
        var clientError: NSError?
        let request = client.URLRequestWithMethod("GET", URL: "https://api.twitter.com/1.1/search/tweets.json?q=%40Peek", parameters: [:], error: &clientError)
        client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
            if let ce = connectionError {
                print("Error: \(ce)")
            }
            
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: [])
                if let statuses = json["statuses"] as? [AnyObject] {
                    weakSelf?.tweets = TWTRTweet.tweetsWithJSONArray(statuses) as! [TWTRTweet]
                    dispatch_async(dispatch_get_main_queue(), { 
                        weakSelf?.tableView.reloadData()
                    })
                }
            } catch let jsonError as NSError {
                print("json error: \(jsonError.localizedDescription)")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tweets.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let tweet = tweets[indexPath.row]
        let cell = TWTRTweetTableViewCell()
        cell.configureWithTweet(tweet)
        cell.tweetView.showActionButtons = true
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let tweet = tweets[indexPath.row]
        return TWTRTweetTableViewCell.heightForTweet(tweet, style: .Compact, width: CGRectGetWidth(self.view.bounds), showingActions: true)
    }

}

