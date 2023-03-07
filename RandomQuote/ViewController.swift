//
//  ViewController.swift
//  RandomQuote
//
//  Created by Tomasz Kubiak on 3/7/23.
//

import UIKit
import Combine

class QuoteViewModel {
    
    enum Input {
        case viewDidAppear
        case refreshButtonDidTap
    }
    
    enum Output {
        case fetchQuoteDidFailed(error: Error)
        case fetchQuoteDidSucceed(quote: Quote)
        case toggleButton(isEnabled: Bool)
    }
    
    // Dependency injection
    private let quoteServiceType: QuoteServiceType
    
    private let output: PassthroughSubject<Output, Never> = .init()
    private var subscriptions = Set<AnyCancellable>()
    
    init(quoteServiceType: QuoteServiceType = QuoteService()) {
        self.quoteServiceType = quoteServiceType
    }
    
    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never> {
        input.sink(receiveValue: { [weak self] event in
            switch event {
            case .viewDidAppear, .refreshButtonDidTap:
                self?.handleGetRandomQuote()
            }
        }).store(in: &subscriptions)
        
        
        return output.eraseToAnyPublisher()
    }
    
    private func handleGetRandomQuote() {
        quoteServiceType.getRandomQuote().sink(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                self.output.send(.fetchQuoteDidFailed(error: error))
            }
        }, receiveValue: { [weak self] quote in
            self?.output.send(.fetchQuoteDidSucceed(quote: quote))
        })
        .store(in: &subscriptions)
    }
}

class ViewController: UIViewController {

    private let vm = QuoteViewModel()
    private let input: PassthroughSubject<QuoteViewModel.Input, Never> = .init()
    private var subscriptions = Set<AnyCancellable>()
    
    @IBOutlet weak var quoteLabel: UILabel!
    @IBOutlet weak var refreshButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        input.send(.viewDidAppear)
    }
    
    private func bind() {
        let output = vm.transform(input: input.eraseToAnyPublisher())
        output
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] event in
            switch event {
            case .toggleButton(isEnabled: let isEnabled):
                self?.refreshButton.isEnabled = isEnabled
            case .fetchQuoteDidSucceed(quote: let quote):
                self?.quoteLabel.text = quote.content
            case .fetchQuoteDidFailed(error: let error):
                self?.quoteLabel.text = error.localizedDescription
            }
        }).store(in: &subscriptions)
    }
    
    
    @IBAction func refreshButtonTapped(_ sender: Any) {
        input.send(.refreshButtonDidTap)
    }
    
}

protocol QuoteServiceType {
    func getRandomQuote() -> AnyPublisher<Quote, Error>
}

class QuoteService: QuoteServiceType {
    
    func getRandomQuote() -> AnyPublisher<Quote, Error> {
        
        let url = URL(string: "https://api.quotable.io/random")!
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .catch { error in
                return Fail(error: error).eraseToAnyPublisher()
            }
            .map { $0.data }
            .decode(type: Quote.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
        
    }
}

struct Quote: Decodable {
    let content: String
    let author: String
}
