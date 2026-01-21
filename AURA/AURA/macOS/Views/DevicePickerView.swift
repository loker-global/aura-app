import Cocoa

/// Audio device picker view
/// (from DEVICE-SWITCHING-UX.md)
final class DevicePickerView: NSView {
    
    // MARK: - Properties
    
    var onDeviceSelected: ((AudioDevice) -> Void)?
    
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var devices: [AudioDevice] = []
    private var selectedDevice: AudioDevice?
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    // MARK: - Setup
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.094, green: 0.102, blue: 0.133, alpha: 1.0).cgColor
        layer?.cornerRadius = 8
        
        // Create table view
        tableView = NSTableView()
        tableView.backgroundColor = .clear
        tableView.rowHeight = 44
        tableView.headerView = nil
        tableView.selectionHighlightStyle = .regular
        tableView.delegate = self
        tableView.dataSource = self
        
        // Add column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("device"))
        column.width = bounds.width - 20
        tableView.addTableColumn(column)
        
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
    }
    
    // MARK: - Data
    
    func setDevices(_ devices: [AudioDevice], selected: AudioDevice?) {
        self.devices = devices
        self.selectedDevice = selected
        tableView.reloadData()
        
        if let selected = selected, let index = devices.firstIndex(of: selected) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
    }
}

// MARK: - NSTableViewDataSource

extension DevicePickerView: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return devices.count
    }
}

// MARK: - NSTableViewDelegate

extension DevicePickerView: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = devices[row]
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("DeviceCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? DeviceCell
        
        if cell == nil {
            cell = DeviceCell()
            cell?.identifier = cellIdentifier
        }
        
        cell?.configure(with: device, isSelected: device == selectedDevice)
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < devices.count else { return }
        
        let device = devices[selectedRow]
        selectedDevice = device
        onDeviceSelected?(device)
        tableView.reloadData()
    }
}

// MARK: - Device Cell

private class DeviceCell: NSTableCellView {
    
    private var nameLabel: NSTextField!
    private var detailLabel: NSTextField!
    private var checkmark: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = NSColor(white: 0.9, alpha: 1.0)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)
        
        detailLabel = NSTextField(labelWithString: "")
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = NSColor(white: 0.6, alpha: 1.0)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(detailLabel)
        
        checkmark = NSTextField(labelWithString: "✓")
        checkmark.font = .systemFont(ofSize: 14, weight: .semibold)
        checkmark.textColor = NSColor(white: 0.9, alpha: 1.0)
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkmark)
        
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            
            checkmark.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            checkmark.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func configure(with device: AudioDevice, isSelected: Bool) {
        nameLabel.stringValue = device.name
        detailLabel.stringValue = device.manufacturer
        checkmark.isHidden = !isSelected
    }
}
