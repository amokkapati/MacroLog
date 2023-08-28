import SwiftUI
import AVFoundation

struct FoodItem: Identifiable, Codable {
    var id: UUID = UUID()
    let name: String
    let calories: Int
    let protein: Int
}

class MacroLog: ObservableObject {
    @Published var foodItems: [FoodItem] = []
    
    var totalCalories: Int {
        foodItems.reduce(0) { $0 + $1.calories }
    }
    
    var totalProtein: Int {
        foodItems.reduce(0) { $0 + $1.protein }
    }
    
    init() {
        loadFoodItems()
    }
    
    func loadFoodItems() {
        if let data = UserDefaults.standard.data(forKey: "foodItems"),
           let savedFoodItems = try? JSONDecoder().decode([FoodItem].self, from: data) {
            foodItems = savedFoodItems
        }
    }   
    
    func saveFoodItems() {
        if let encodedData = try? JSONEncoder().encode(foodItems) {
            UserDefaults.standard.set(encodedData, forKey: "foodItems")
        }
    }
    
    func addFoodItem(name: String, calories: Int, protein: Int) {
        let newItem = FoodItem(name: name, calories: calories, protein: protein)
        foodItems.append(newItem)
        saveFoodItems()
    }
    
    func deleteFoodItem(at indexSet: IndexSet) {
        foodItems.remove(atOffsets: indexSet)
        saveFoodItems()
    }
}

struct ContentView: View {
    @ObservedObject var tracker = MacroLog()
    @State private var foodName = ""
    @State private var calorieCount = ""
    @State private var proteinCount = ""
    @State private var isShowingScanner = false
    @State private var scannedFoodItem: FoodItem?
    
    var body: some View {
        VStack {
            Text("Macro Log")
                .font(.title)
                .padding()
            
            HStack {
                TextField("Food Name", text: $foodName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .keyboardType(.default) // Use .default keyboard type
                    .onTapGesture {
                        // Dismiss the keyboard when tapping outside the text field
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                TextField("Calorie Count", text: $calorieCount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding()
                    .keyboardType(.default) // Use .default keyboard type
                    .onTapGesture {
                        // Dismiss the keyboard when tapping outside the text field
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                TextField("Protein Count", text: $proteinCount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding()
                    .keyboardType(.default) // Use .default keyboard type
                    .onTapGesture {
                        // Dismiss the keyboard when tapping outside the text field
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                Button(action: {
                    guard let calories = Int(calorieCount) else { return }
                    guard let protein = Int(proteinCount) else { return }
                    tracker.addFoodItem(name: foodName, calories: calories, protein: protein)
                    foodName = ""
                    calorieCount = ""
                    proteinCount = ""
                    
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    
                }) {
                    Text("Add")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .fixedSize()
                }
                .padding()
            }
            
            Button(action: {
                isShowingScanner = true
            }) {
                Text("Scan Barcode")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .fixedSize()
            }
            .padding()
            
            List {
                ForEach(tracker.foodItems) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text("\(item.calories) calories")
                    }
                }
                .onDelete(perform: tracker.deleteFoodItem)
            }
            
            Text("\(tracker.totalCalories) Calories")
                .font(.title2)
                .padding()
            Text(" \(tracker.totalProtein)g Protein")
                .font(.title2)
                .padding()
            Spacer()
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView(scannedFoodItem: $scannedFoodItem)
                .onDisappear {
                    if let scannedItem = scannedFoodItem {
                        tracker.addFoodItem(name: scannedItem.name, calories: scannedItem.calories, protein: scannedItem.protein)
                        scannedFoodItem = nil
                    }
                }
        }
    }
}

struct BarcodeScannerView: View {
    @Binding var scannedFoodItem: FoodItem?
    @State private var isShowingScanner = true
    
    var body: some View {
        ZStack {
            if isShowingScanner {
                ScannerView(scannedFoodItem: $scannedFoodItem, isShowingScanner: $isShowingScanner)
            }
        }
    }
}

struct ScannerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = ScannerViewController
    
    @Binding var scannedFoodItem: FoodItem?
    @Binding var isShowingScanner: Bool
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let viewController = ScannerViewController()
        viewController.scannerDelegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // No need for implementation here
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, ScannerDelegate {
        let parent: ScannerView
        
        init(parent: ScannerView) {
            self.parent = parent
        }
        
        func didScanBarcode(withData data: String) {
            // Example implementation to parse barcode data
            // Modify this logic based on the barcode scanner library you are using
            
            // Assuming the barcode data is in the format: "name:calories:protein"
            let components = data.components(separatedBy: ":")
            guard components.count == 3,
                  let calories = Int(components[1]),
                  let protein = Int(components[2]) else {
                return
            }
            
            let scannedItem = FoodItem(name: components[0], calories: calories, protein: protein)
            parent.scannedFoodItem = scannedItem
            parent.isShowingScanner = false
        }
    }
}

protocol ScannerDelegate: AnyObject {
    func didScanBarcode(withData data: String)
}

class ScannerViewController: UIViewController {
    weak var scannerDelegate: ScannerDelegate?
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the capture session and preview layer
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            print("Failed to set up video capture.")
            return
        }
        
        captureSession.addInput(videoInput)
        captureSession.startRunning()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        // Add UI elements and buttons for scanning
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.frame = CGRect(x: 20, y: 40, width: 60, height: 30)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        let scanButton = UIButton(type: .system)
        scanButton.setTitle("Scan", for: .normal)
        scanButton.frame = CGRect(x: view.bounds.width - 80, y: 40, width: 60, height: 30)
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        view.addSubview(scanButton)
    }
    
    @objc func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func scanButtonTapped() {
        // Simulate barcode scanning for demonstration purposes
        let scannedData = "ExampleFood:200:10"
        scannerDelegate?.didScanBarcode(withData: scannedData)
        dismiss(animated: true, completion: nil)
    }
}


struct BarcodeScannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

