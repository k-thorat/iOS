//
//  MainViewController.swift
//  DuckDuckGo
//
//  Created by Mia Alexiou on 24/01/2017.
//  Copyright © 2017 DuckDuckGo. All rights reserved.
//

import UIKit
import WebKit
import Core

class MainViewController: UIViewController {
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var tabsButton: UIBarButtonItem!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var forwardButton: UIBarButtonItem!
    
    fileprivate var autocompleteController: AutocompleteViewController?
    
    fileprivate lazy var groupData = GroupData()
    fileprivate lazy var settings = Settings()
    fileprivate lazy var tabManager = TabManager()
    
    weak var omniBar: OmniBar?
    
    fileprivate var currentTab: Tab? {
        return tabManager.current
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        attachHomeTab()
    }
    
    func attachHomeTab() {
        let tab = HomeViewController.loadFromStoryboard()
        tabManager.add(tab: tab)
        tab.tabDelegate = self
        addToView(tab: tab)
    }
    
    func attachWebTab(forUrl url: URL) {
        let tab = WebTabViewController.loadFromStoryboard()
        tabManager.add(tab: tab)
        tab.tabDelegate = self
        tab.load(url: url)
        addToView(tab: tab)
    }
    
    func attachSiblingWebTab(fromWebView webView: WKWebView, forUrl url: URL) {
        let tab = WebTabViewController.loadFromStoryboard()
        tab.attachWebView(newWebView: webView.createSiblingWebView())
        tab.tabDelegate = self
        tabManager.add(tab: tab)
        tab.load(url: url)
        addToView(tab: tab)
    }
    
    func addToView(tab: UIViewController) {
        tab.view.frame = containerView.frame
        tab.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addChildViewController(tab)
        containerView.addSubview(tab.view)
        if let tab = tab as? Tab {
            resetOmniBar(withStyle: tab.omniBarStyle)
        }
    }
    
    func resetOmniBar(withStyle style: OmniBar.Style) {
        if omniBar?.style == style {
            return
        }
        omniBar = OmniBar.loadFromXib(withStyle: style)
        omniBar?.omniDelegate = self
        navigationItem.titleView = omniBar
    }
    
    func refreshControls() {
        refreshOmniText()
        refreshTabIcon()
        refreshNavigationButtons()
    }
    
    func refreshTabIcon() {
        refreshTabIcon(count: tabManager.count)
    }
    
    func refreshTabIcon(count: Int) {
        tabsButton.image = TabIconMaker().icon(forTabs: count)
    }
    
    private func refreshNavigationButtons() {
        backButton.isEnabled = currentTab?.canGoBack ?? false
        forwardButton.isEnabled = currentTab?.canGoForward ?? false
    }
    
    private func refreshOmniText() {
        guard let tab = currentTab else {
            return
        }
        if tab.showsUrlInOmniBar {
            omniBar?.refreshText(forUrl: tab.url)
        } else {
            omniBar?.clear()
        }
    }
    
    @IBAction func onBackPressed(_ sender: UIBarButtonItem) {
        currentTab?.goBack()
    }
    
    @IBAction func onForwardPressed(_ sender: UIBarButtonItem) {
        currentTab?.goForward()
    }
    
    @IBAction func onSharePressed(_ sender: UIBarButtonItem) {
        if let url = currentTab?.url {
            presentShareSheet(withItems: [url], fromButtonItem: sender)
        }
    }
    
    @IBAction func onSaveQuickLink(_ sender: UIBarButtonItem) {
        if let link = currentTab?.link {
            groupData.addQuickLink(link: link)
            makeToast(text: UserText.webSaveLinkDone)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? TabViewController {
            onTabViewControllerSegue(controller: controller)
            return
        }
    }
    
    private func onTabViewControllerSegue(controller: TabViewController) {
        controller.delegate = self
    }
    
    func makeToast(text: String) {
        let x = view.bounds.size.width / 2.0
        let y = view.bounds.size.height - 80
        view.makeToast(text, duration: ToastManager.shared.duration, position: CGPoint(x: x, y: y))
    }
    
    func displayAutocompleteSuggestions(forQuery query: String) {
        if autocompleteController == nil {
            let controller = AutocompleteViewController.loadFromStoryboard()
            controller.delegate = self
            addChildViewController(controller)
            containerView.addSubview(controller.view)
            autocompleteController = controller
        }
        guard let autocompleteController = autocompleteController else { return }
        autocompleteController.updateQuery(query: query)
        omniBar?.becomeFirstResponder()
    }
    
    func dismissAutcompleteSuggestions() {
        guard let controller = autocompleteController else { return }
        controller.view.removeFromSuperview()
        controller.removeFromParentViewController()
        omniBar?.resignFirstResponder()
        currentTab?.omniBarWasDismissed()
        autocompleteController = nil
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        dismissAutcompleteSuggestions()
    }
}

extension MainViewController: OmniBarDelegate {
    
    func onOmniQueryUpdated(_ updatedQuery: String) {
        displayAutocompleteSuggestions(forQuery: updatedQuery)
    }
    
    func onOmniQuerySubmitted(_ query: String) {
        dismissAutcompleteSuggestions()
        if let url = AppUrls.url(forQuery: query) {
            currentTab?.load(url: url)
        }
    }
    
    func onActionButtonPressed() {
        clearAllTabs()
    }
    
    func onRefreshButtonPressed() {
        currentTab?.reload()
    }
    
    func onDismissButtonPressed() {
        dismissAutcompleteSuggestions()
    }
}

extension MainViewController: AutocompleteViewControllerDelegate {
    
    func autocomplete(selectedSuggestion suggestion: String) {
        dismissAutcompleteSuggestions()
        if let queryUrl = AppUrls.url(forQuery: suggestion) {
            currentTab?.load(url: queryUrl)
        }
    }
}

extension MainViewController: HomeTabDelegate {
    
    func activateOmniBar() {
        omniBar?.becomeFirstResponder()
    }
    
    func deactivateOmniBar() {
        omniBar?.resignFirstResponder()
        omniBar?.clear()
    }
    
    func loadNewWebQuery(query: String) {
        if let url = AppUrls.url(forQuery: query) {
            loadNewWebUrl(url: url)
        }
    }
    
    func loadNewWebUrl(url: URL) {
        loadViewIfNeeded()
        let homeTab = currentTab as? HomeViewController
        attachWebTab(forUrl: url)
        if let oldTab = homeTab {
            tabManager.remove(tab: oldTab)
        }
        refreshControls()
    }
    
    func launchTabsSwitcher() {
        let controller = TabViewController.loadFromStoryboard()
        controller.delegate = self
        controller.modalPresentationStyle = .overCurrentContext
        present(controller, animated: true, completion: nil)
    }
}

extension MainViewController: WebTabDelegate {
    
    func openNewTab(fromWebView webView: WKWebView, forUrl url: URL) {
        refreshTabIcon(count: tabManager.count+1)
        attachSiblingWebTab(fromWebView: webView, forUrl: url)
        refreshControls()
    }
    
    func resetAll() {
        clearAllTabs()
    }
}

extension MainViewController: TabViewControllerDelegate {
    
    var tabDetails: [Link] {
        return tabManager.tabDetails
    }
    
    func createTab() {
        attachHomeTab()
        refreshControls()
    }
    
    func select(tabAt index: Int) {
        let selectedTab = tabManager.select(tabAt: index) as! UIViewController
        addToView(tab: selectedTab)
        refreshControls()
    }
    
    func remove(tabAt index: Int) {
        tabManager.remove(at: index)
        
        if tabManager.isEmpty {
            createTab()
        }
        
        if let lastIndex = tabManager.lastIndex, index > lastIndex {
            select(tabAt: lastIndex)
            return
        }
        
        select(tabAt: index)
    }
    
    func clearAllTabs() {
        tabManager.clearAll()
        createTab()
    }
}
