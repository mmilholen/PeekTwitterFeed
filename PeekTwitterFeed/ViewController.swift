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
    var locked = false
    var nextResultsUrl = ""
    var refreshUrl = ""
    
    let SearchUrl = "https://api.twitter.com/1.1/search/tweets.json"
    
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
        guard !locked else { return }
        locked = true
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        weak var weakSelf = self
        var clientError: NSError?
        let request = client.URLRequestWithMethod("GET", URL: "\(SearchUrl)?q=%40Peek", parameters: [:], error: &clientError)
        client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
            // guard block connection failure
            if let ce = connectionError {
                print("Error: \(ce)")
                dispatch_async(dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                })
                weakSelf?.locked = false
                return
            }
            
            // parse results
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableContainers) as! NSDictionary
//                print("json: \(json)")
                if let metadata = json["search_metadata"] {
                    if let nru = metadata["next_results"] as? String {
                        weakSelf?.nextResultsUrl = nru
                    } else {
                        weakSelf?.nextResultsUrl = ""
                    }
                    if let ru = metadata["refresh_url"] as? String {
                        weakSelf?.refreshUrl = ru
                    } else {
                        weakSelf?.refreshUrl = ""
                    }
                }
                if let statuses = json["statuses"] as? [AnyObject] {
                    weakSelf?.tweets = TWTRTweet.tweetsWithJSONArray(statuses) as! [TWTRTweet]
                    dispatch_async(dispatch_get_main_queue(), {
                        weakSelf?.tableView.reloadData()
                    })
                }
            } catch let jsonError as NSError {
                print("json error: \(jsonError.localizedDescription)")
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            })
            weakSelf?.locked = false
        }
    }
    
    private func fetchNextTweets() {
        guard !locked && !nextResultsUrl.isEmpty else { return }
        locked = true
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        weak var weakSelf = self
        var clientError: NSError?
        let request = client.URLRequestWithMethod("GET", URL: "\(SearchUrl)\(nextResultsUrl)", parameters: [:], error: &clientError)
        client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
            // guard block connection failure
            if let ce = connectionError {
                print("Error: \(ce)")
                dispatch_async(dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                })
                weakSelf?.locked = false
                return
            }
            
            // parse results
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableContainers) as! NSDictionary
//                print("json: \(json)")
                
                // parse search metadata
                if let metadata = json["search_metadata"], let nru = metadata["next_results"] as? String {
                    weakSelf?.nextResultsUrl = nru
                } else {
                    weakSelf?.nextResultsUrl = ""
                }
                
                // parse tweets
                if let statuses = json["statuses"] as? [AnyObject] {
                    weakSelf?.tweets.appendContentsOf(TWTRTweet.tweetsWithJSONArray(statuses) as! [TWTRTweet])
                    dispatch_async(dispatch_get_main_queue(), {
                        weakSelf?.tableView.reloadData()
                    })
                }
            } catch let jsonError as NSError {
                print("json error: \(jsonError.localizedDescription)")
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            })
            weakSelf?.locked = false
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
    
    // MARK: - UITableViewDelegate
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let tweet = tweets[indexPath.row]
        return TWTRTweetTableViewCell.heightForTweet(tweet, style: .Compact, width: CGRectGetWidth(self.view.bounds), showingActions: true)
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        let bottom = scrollView.contentOffset.y + scrollView.bounds.size.height
        if bottom >= scrollView.contentSize.height {
            fetchNextTweets()
        }
    }

}

