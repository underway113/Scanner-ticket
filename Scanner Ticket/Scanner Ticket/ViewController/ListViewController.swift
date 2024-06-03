//
//  ListViewController.swift
//  Scanner Ticket
//
//  Created by Jeremy Adam on 31/05/24.
//

import FirebaseFirestore
import UIKit
import AVFoundation

class ListViewController: UIViewController {

    public var currentURLIndex: Int = 0
    let db = Firestore.firestore()
    var participants: Set<Participant> = []
    var filteredParticipants: Set<Participant> = []

    var tableView = UITableView()
    var searchBar = UISearchBar()
    var infoView = UIView()
    var totalParticipantsLabel = UILabel()
    var statusLabel = UILabel()
    var emptyImageView = UIImageView()
    var emptyLabel = UILabel()
    var activityIndicator = UIActivityIndicatorView(style: .large)
    var refreshControl = UIRefreshControl()
    var filterButton = UIButton(type: .system)
    var filterMode: FilterMode = .all

    enum FilterMode {
        case all, trueOnly, falseOnly
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar()
        setupSearchBar()
        setupFilterButton()
        setupInfoView()
        setupTableView()
        setupEmptyView()
        setupActivityIndicator()
    }

    override func viewWillAppear(_ animated: Bool) {
        fetchParticipants()
    }

    private func configureNavigationBar() {
        guard let ticketType = TicketTypeEnum(rawValue: currentURLIndex) else {
            self.navigationItem.title = "ERROR"
            return
        }
        title = ticketType.title
        navigationController?.navigationBar.backgroundColor = ticketType.backgroundColor
        navigationController?.navigationBar.tintColor = .white
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addParticipant))
    }

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        ])
    }

    private func setupInfoView() {
        infoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoView)

        totalParticipantsLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        infoView.addSubview(totalParticipantsLabel)
        infoView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            infoView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            infoView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            infoView.heightAnchor.constraint(equalToConstant: 50),

            totalParticipantsLabel.leadingAnchor.constraint(equalTo: infoView.leadingAnchor),
            totalParticipantsLabel.centerYAnchor.constraint(equalTo: infoView.centerYAnchor),

            statusLabel.trailingAnchor.constraint(equalTo: infoView.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: infoView.centerYAnchor)
        ])
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.refreshControl = refreshControl
        tableView.keyboardDismissMode = .interactive
        refreshControl.addTarget(self, action: #selector(refreshParticipants), for: .valueChanged)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: infoView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView.register(ParticipantTableViewCell.self, forCellReuseIdentifier: "cell")
    }

    private func setupEmptyView() {
        emptyLabel.text = "Data Not Found"
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyImageView.image = UIImage(named: "not-found")
        emptyImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        view.addSubview(emptyImageView)

        NSLayoutConstraint.activate([
            emptyImageView.widthAnchor.constraint(equalToConstant: 100),
            emptyImageView.heightAnchor.constraint(equalToConstant: 100),
            emptyImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            emptyLabel.topAnchor.constraint(equalTo: emptyImageView.bottomAnchor, constant: 10),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        emptyLabel.isHidden = true
        emptyImageView.isHidden = true
    }

    private func setupActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupFilterButton() {
        let btnImage = UIImage(named: "filter-all")
        filterButton.tintColor = .white
        filterButton.setImage(btnImage , for: .normal)
        filterButton.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterButton)

        NSLayoutConstraint.activate([
            filterButton.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            filterButton.leadingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: 8),
            filterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            filterButton.widthAnchor.constraint(equalToConstant: 24),
            filterButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func fetchParticipants() {
        showActivityIndicator()
        db.collection("Participants")
            .order(by: "name")
            .getDocuments { [weak self] (querySnapshot, error) in
                self?.hideActivityIndicator()
                guard let self = self else { return }
                if let error = error {
                    AlertManager.showErrorAlert(with: "Error fetching participants: \(error.localizedDescription)", completion: {})
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    print("Error fetching documents")
                    return
                }

                self.participants = ParticipantUtil.parseToSetParticipants(documents)
                self.applyFilter()
                self.updateEmptyViewVisibility()
                self.updateInfoLabels()
                self.tableView.reloadData()
            }
    }

    private func updateEmptyViewVisibility() {
        let isEmpty = filteredParticipants.isEmpty
        emptyImageView.isHidden = !isEmpty
        emptyLabel.isHidden = !isEmpty
    }

    private func updateInfoLabels() {
        let totalParticipants = participants.count
        var trueCount = 0
        var falseCount = 0

        for participant in participants {
            let value = getDisplayValue(for: participant)
            if value {
                trueCount += 1
            } else {
                falseCount += 1
            }
        }

        totalParticipantsLabel.text = "Total: \(totalParticipants)"
        statusLabel.text = "\(trueCount) scanned / \(falseCount) not scanned"
    }

    @objc private func addParticipant() {
        let alert = UIAlertController(title: "Add New Participant", message: "Enter name", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Name"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            showActivityIndicator()
            Task {
                if let name = alert.textFields?.first?.text, !name.isEmpty {
                    do {
                        let exists = try await self.checkIfNameExists(name)
                        if exists {
                            self.hideActivityIndicator()
                            AlertManager.showErrorAlert(with: "A participant with this name already exists.", completion: {})
                        } 
                        else {
                            var newDocumentID: String
                            var isUnique: Bool
                            repeat {
                                newDocumentID = String.randomDocumentID(length: 5)
                                isUnique = try await self.checkDocumentIDExists(documentID: newDocumentID)
                            } while !isUnique

                            let detailVC = DetailViewController()
                            detailVC.documentID = newDocumentID
                            detailVC.name = name
                            detailVC.isNewParticipant = true
                            self.navigationController?.pushViewController(detailVC, animated: true)
                        }
                    } 
                    catch {
                        self.hideActivityIndicator()
                        AlertManager.showErrorAlert(with: "Error checking name: \(error.localizedDescription)", completion: {})
                    }
                }
            }
        }))
        hideActivityIndicator()
        present(alert, animated: true, completion: nil)
    }

    private func checkDocumentIDExists(documentID: String) async throws -> Bool {
        let docRef = db.collection("Participants").document(documentID)
        let document = try await docRef.getDocument()
        return !document.exists
    }

    private func checkIfNameExists(_ name: String) async throws -> Bool {
        let querySnapshot = try await db.collection("Participants").whereField("name", isEqualTo: name).getDocuments()
        return !querySnapshot.documents.isEmpty
    }

    private func showActivityIndicator() {
        activityIndicator.startAnimating()
    }

    private func hideActivityIndicator() {
        activityIndicator.stopAnimating()
    }

    @objc private func refreshParticipants() {
        fetchParticipants()
        refreshControl.endRefreshing()
    }

    @objc private func filterButtonTapped() {
        switch filterMode {
        case .all:
            filterMode = .trueOnly
        case .trueOnly:
            filterMode = .falseOnly
        case .falseOnly:
            filterMode = .all
        }
        applyFilter()
        tableView.reloadData()
    }

    private func applyFilter() {
        switch filterMode {
        case .all:
            let btnImage = UIImage(named: "filter-all")
            filterButton.setImage(btnImage , for: .normal)
            filteredParticipants = participants
        case .trueOnly:
            let btnImage = UIImage(named: "check-white")
            filterButton.setImage(btnImage , for: .normal)
            filteredParticipants = participants.filter { getDisplayValue(for: $0) }
        case .falseOnly:
            let btnImage = UIImage(named: "cross-white")
            filterButton.setImage(btnImage , for: .normal)
            filteredParticipants = participants.filter { !getDisplayValue(for: $0) }
        }
        updateEmptyViewVisibility()
    }
}

extension ListViewController: UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredParticipants.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as? ParticipantTableViewCell else {
            return UITableViewCell()
        }

        let participant = getSortedFilteredParticipant(at: indexPath.row)
        let displayValue = getDisplayValue(for: participant)

        cell.configure(id: participant.documentID, name: participant.name, value: displayValue)
        cell.backgroundColor = getBackgroundColor(for: displayValue)

        return cell
    }

    private func getSortedFilteredParticipant(at index: Int) -> Participant {
        return Array(filteredParticipants).sorted(by: { $0.name < $1.name })[index]
    }

    private func getDisplayValue(for participant: Participant) -> Bool {
        switch TicketTypeEnum(rawValue: currentURLIndex) {
        case .participantKit:
            return participant.participantKit
        case .entry:
            return participant.entry
        case .mainFood:
            return participant.mainFood
        case .snack:
            return participant.snack
        case .none:
            return false
        }
    }

    private func getBackgroundColor(for displayValue: Bool) -> UIColor {
        let darkerGreen = UIColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
        let darkerRed = UIColor(red: 0.5, green: 0.0, blue: 0.0, alpha: 1.0)
        return displayValue ? darkerGreen : darkerRed
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let participant = getSortedFilteredParticipant(at: indexPath.row)
        let detailVC = DetailViewController()
        detailVC.documentID = participant.documentID
        detailVC.name = participant.name
        detailVC.participantKit = participant.participantKit
        detailVC.entry = participant.entry
        detailVC.mainFood = participant.mainFood
        detailVC.snack = participant.snack
        detailVC.isNewParticipant = false
        navigationController?.pushViewController(detailVC, animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredParticipants = searchText.isEmpty ? participants : filterParticipants(by: searchText)
        filterButton.setTitle("ALL", for: .normal)
        updateEmptyViewVisibility()
        updateInfoLabels()
        tableView.reloadData()
    }

    private func filterParticipants(by searchText: String) -> Set<Participant> {
        return participants.filter { participant in
            let matchesName = participant.name.lowercased().contains(searchText.lowercased())
            let matchesDocumentID = participant.documentID.lowercased().contains(searchText.lowercased())
            return matchesName || matchesDocumentID
        }
    }
}
