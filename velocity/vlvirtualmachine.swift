//
//  vlvirtualmachine.swift
//  velocity
//
//  Created by Max Kofler on 01/06/23.
//

import Foundation
import Virtualization

class VVMDelegate: NSObject { }
extension VVMDelegate: VZVirtualMachineDelegate {
    
    //MARK: How do we handle this callback?
    //MARK: Probably pretty easy?
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("The guest shut down or crashed. Exiting.")
        //exit(EXIT_SUCCESS)
    }
}

enum VMState: Codable {
    case RUNNING
    case STOPPED
    case SHUTTING_DOWN
    case CRASHED
    case ABORTED
}

public struct VirtualMachine: Codable {
    var vm_state: VMState
    var vm_info: VMProperties
    
    init(vm_state: VMState, vm_info: VMProperties) {
        self.vm_state = vm_state
        self.vm_info = vm_info
    }
}

public class VLVirtualMachine : VZVirtualMachine {
    let window: VWindow;
    let vm_delegate: VVMDelegate;
    let vm_info: VMProperties;
    var vm_state: VMState;
    var vm_config: VZVirtualMachineConfiguration;

    /// Creates a new VLVirtualMachine from the supplied information
    /// - Parameter vm_config: The VZVirtualMachineConfiguration to use for vm creation
    init(vm_config: VZVirtualMachineConfiguration, vm_info: VMProperties) {
        self.vm_delegate = VVMDelegate();
        self.vm_config = vm_config;
        self.vm_info = vm_info;
        let vm_view = VZVirtualMachineView();
        vm_view.setFrameSize(self.vm_info.screen_size);

        self.window = VWindow(vm_view: vm_view);

        // The VM is stopped upon creation
        self.vm_state = VMState.STOPPED;

        VDebug("HACK: Setting Activation Policy to accessory to Hide NSWindow..")
        NSApp.setActivationPolicy(.accessory)

        super.init(configuration: self.vm_config, queue: DispatchQueue.main);

        vm_view.virtualMachine = self;
        self.delegate = self.vm_delegate;
    }

    /// Sends the provided keycode to the virtual machine
    /// - Parameter key_code: The code to send
    func send_key_event(key_code: UInt16) {
        let key_event = NSEvent.keyEvent(with: .keyDown, location: NSPoint.zero, modifierFlags: [], timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: key_code)
        
        let key_release_event = NSEvent.keyEvent(with: .keyUp, location: NSPoint.zero, modifierFlags: [], timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: key_code)
        
        // Execute keyDown immediately
        if let key_event = key_event {
            DispatchQueue.main.async {
                self.window.vm_view.keyDown(with: key_event)
            }
        }
        
        //Execute keyUp with 0.1 delay
        if let key_release_event = key_release_event {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.window.vm_view.keyUp(with: key_release_event)
            }
        }
    }

    /// Returns the VirtualMachine information for JSON serialization
    func get_vm() -> VirtualMachine {
        return VirtualMachine(vm_state: self.vm_state, vm_info: self.vm_info);
    }

    /// Returns the currently displayed frame data
    func get_cur_screen_contents() -> Data? {
        return self.window.cur_frame?.pngData;
    }
}
