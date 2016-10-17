//
//  CardsViewController.swift
//  MyCards
//
//  Created by Maciej Piotrowski on 16/10/16.
//  Copyright © 2016 Maciej Piotrowski. All rights reserved.
//

import UIKit


final class CardsViewController: UIViewController {
    
    fileprivate let worker: CoreDataWorkerProtocol
    fileprivate var cards: [Card] = [Card(name: "Card 1"),
                                     Card(name: "Card 2"),
                                     Card(name: "Card 3"),
                                     Card(name: "Card 4"),
                                     Card(name: "Card 5"),
                                     Card(name: "Card 6"),
                                     Card(name: "Card 7"),
                                     Card(name: "Card 8"),
                                     ]
    fileprivate var collectionView: UICollectionView!
    fileprivate let reuseIdentifier: String = String(describing: CardCell.self)
    
    init(worker: CoreDataWorkerProtocol) {
        self.worker = worker
        super.init(nibName: nil, bundle: nil)
        self.title = "My Cards"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureNavigationItem()
        configureConstraints()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        collectionView.reloadData()
    }
    
    func configureView() {
        view.backgroundColor = . white
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = CGSize(width: view.bounds.size.width * 0.8, height: 200)
        let offset: CGFloat = 20
        layout.sectionInset = UIEdgeInsets(top: offset, left: offset, bottom: offset, right: offset)
        layout.minimumInteritemSpacing = offset
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CardCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        view.addSubview(collectionView)
    }
    
    func configureNavigationItem() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
    }
    
    func configureConstraints() {
        view.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        var constraints: [NSLayoutConstraint] = []
        
        let views: [String : Any] = [
            "collectionView" : collectionView,
            ]
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|[collectionView]|", options: [], metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|[collectionView]|", options: [], metrics: nil, views: views)
        
        NSLayoutConstraint.activate(constraints)
        
    }
    
    func addTapped(sender: UIBarButtonItem) {
        showDetails(of: nil)
    }
    
    func showDetails(of card: Card?) {
        let viewController = CardDetailsViewController(card: card)
        let navigationController = UINavigationController(rootViewController: viewController)
        present(navigationController, animated: true, completion: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        //TODO: layout change when rotating
        collectionView.collectionViewLayout.invalidateLayout()
    }
}

extension CardsViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return cards.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        //TODO: safe
        
        let card = cards[indexPath.row]
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                      for: indexPath) as! CardCell
        cell.name = card.name
        cell.front = card.front
        cell.back = card.back
        return cell
    }
}

extension CardsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let card = cards[safe: indexPath.row] else { return }
        showDetails(of: card)
    }
}
