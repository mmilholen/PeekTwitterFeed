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
    var refreshControl: UIRefreshControl!
    
    let twitterFacade = TwitterFacade()
    var tweets = [TWTRTweet]()
    
    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        initRefreshControl()
        
        twitterFacade.authenticate { error in
            if let _ = error { return }
            self.fetchTweets()
        }
    }
    
    private func initRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.backgroundColor = UIColor.yellowColor()
        refreshControl.tintColor = UIColor.purpleColor()
        refreshControl.addTarget(self, action: #selector(ViewController.refreshTweets), forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Data Access
    
    func fetchTweets() {
        weak var weakSelf = self
        twitterFacade.fetchTweets {
            (tweets, error) -> Void in
            if let _ = error {
                // Nothing to do
            } else {
                weakSelf?.tweets = tweets
            }
            dispatch_async(dispatch_get_main_queue(), {
                weakSelf?.tableView.reloadData()
            })
        }
    }
    
    func fetchNextTweets() {
        weak var weakSelf = self
        twitterFacade.fetchNextTweets {
            (tweets, error) -> Void in
            if let _ = error {
                // Nothing to do
            } else {
                weakSelf?.tweets.appendContentsOf(tweets)
            }
            dispatch_async(dispatch_get_main_queue(), {
                weakSelf?.tableView.reloadData()
            })
        }
    }
    
    func refreshTweets() {
        weak var weakSelf = self
        twitterFacade.refreshTweets {
            (tweets, error) -> Void in
            if let _ = error {
                // Nothing to do
            } else {
                weakSelf?.tweets = tweets + (weakSelf?.tweets)! // prepend search results
            }
            dispatch_async(dispatch_get_main_queue(), {
                weakSelf?.refreshControl.endRefreshing()
                weakSelf?.tableView.reloadData()
            })
        }
    }
    
    func removeTweet(tweet: TWTRTweet) {
        tweets = tweets.filter { $0 !== tweet }
        tableView.reloadData()
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
        if bottom >= scrollView.contentSize.height { // did scroll to bottom
            fetchNextTweets()
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        switch editingStyle {
        case .Delete:
            removeTweet(tweets[indexPath.row])
        default: break // Nothing to do
        }
    }

}

