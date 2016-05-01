//
//  TwitterFacade.swift
//  PeekTwitterFeed
//
//  Created by Michael Milholen on 5/1/16.
//  Copyright © 2016 Michael Milholen. All rights reserved.
//

import Foundation
import TwitterKit

class TwitterFacade {
    
    private var client: TWTRAPIClient!
    private var locked = false
    private var nextResultsUrl = ""
    private var refreshUrl = ""
    
    let SearchUrl = "https://api.twitter.com/1.1/search/tweets.json"
    let SearchQuery = "?q=%40Peek"
    
    func authenticate(completion: ((authError: NSError?) -> Void)?) {
        weak var weakSelf = self
        Twitter.sharedInstance().logInWithCompletion { session, error in
            if let s = session {
                weakSelf?.client = TWTRAPIClient(userID: s.userID)
            } else if let e = error {
                print("Authentication Error: \(e.localizedDescription)");
            }
            
            if let c = completion {
                c(authError: error)
            }
        }
    }
    
    func fetchTweets(completion: (([TWTRTweet], NSError?) -> Void)?) {
        weak var weakSelf = self
        executeSeach(SearchQuery) {
            (tweets, refreshUrl, nextResultsUrl, error) -> Void in
            weakSelf?.refreshUrl = refreshUrl
            weakSelf?.nextResultsUrl = nextResultsUrl
            if let c = completion {
                c(tweets, error)
            }
        }
    }
    
    func refreshTweets(completion: (([TWTRTweet], NSError?) -> Void)?) {
        guard !refreshUrl.isEmpty else { return }
        
        weak var weakSelf = self
        executeSeach(refreshUrl) {
            (tweets, refreshUrl, _, error) -> Void in
            weakSelf?.refreshUrl = refreshUrl
            if let c = completion {
                c(tweets, error)
            }
        }
    }
    
    func fetchNextTweets(completion: (([TWTRTweet], NSError?) -> Void)?) {
        guard !nextResultsUrl.isEmpty else { return }
        
        weak var weakSelf = self
        executeSeach(nextResultsUrl) {
            (tweets, _, nextResultsUrl, error) -> Void in
            weakSelf?.nextResultsUrl = nextResultsUrl
            if let c = completion {
                c(tweets, error)
            }
        }
    }
    
    private func executeSeach(queryParameters: String, completion: (tweets: [TWTRTweet], refreshUrl: String, nextResultsUrl: String, error: NSError?) -> Void) {
        guard !locked else { return }
        locked = true
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        weak var weakSelf = self
        var clientError: NSError?
        let request = client.URLRequestWithMethod("GET", URL: "\(SearchUrl)\(queryParameters)", parameters: [:], error: &clientError)
        client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
            var tweets = [TWTRTweet]()
            var nextResultsUrl = ""
            var refreshUrl = ""
            var error: NSError?
            
            // guard block connection failure
            if let ce = connectionError {
                print("Connection Error: \(ce)")
                dispatch_async(dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                })
                weakSelf?.locked = false
                completion(tweets: tweets, refreshUrl: refreshUrl, nextResultsUrl: nextResultsUrl, error: connectionError)
                return
            }
            
            // parse response
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableContainers) as! NSDictionary
                
                // parse search metadata
                if let metadata = json["search_metadata"] {
                    if let nru = metadata["next_results"] as? String {
                        nextResultsUrl = nru
                    }
                    if let ru = metadata["refresh_url"] as? String {
                        refreshUrl = ru
                    }
                }
                
                // parse tweets
                if let statuses = json["statuses"] as? [AnyObject] {
                    tweets = TWTRTweet.tweetsWithJSONArray(statuses) as! [TWTRTweet]
                }
            } catch let jsonError as NSError {
                print("Json Parse Error: \(jsonError.localizedDescription)")
                error = jsonError
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            })
            weakSelf?.locked = false
            completion(tweets: tweets, refreshUrl: refreshUrl, nextResultsUrl: nextResultsUrl, error: error)
        }
    }
}