//
//  manager.swift
//  velocity
//
//  Created by zimsneexh on 26.05.23.
//

import Foundation
import Virtualization

internal struct VelocityVMMError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
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

// Non-Serializable VM Object for internal data
public struct VirtualMachineExt {
    var virtual_machine: VirtualMachine
    var vm_view: NSView
    var window_id: UInt32
    var vz_virtual_machine: VZVirtualMachine
    
    init(virtual_machine: VirtualMachine, vm_view: NSView, window_id: UInt32, vz_virtual_machine: VZVirtualMachine) {
        self.virtual_machine = virtual_machine
        self.vm_view = vm_view
        self.window_id = window_id
        self.vz_virtual_machine = vz_virtual_machine
    }
}

typealias availableVMList = [VMProperties]
typealias VMList = [VirtualMachineExt]

struct Manager {
    static var running_vms: VMList = [ ]
    static var available_vms: availableVMList = [ ]
    
    //
    // Indexes the local storage on startup
    //
    static func index_storage(velocity_config: VelocityConfig) throws {
        do {
            let directory_content = try FileManager.default.contentsOfDirectory(atPath: velocity_config.velocity_bundle_dir.absoluteString)
            
            for url in directory_content {
                let velocity_json = velocity_config.velocity_bundle_dir.appendingPathComponent(url).appendingPathComponent("Velocity.json").absoluteString
                
                if FileManager.default.fileExists(atPath: velocity_json) {
                    let decoder = JSONDecoder()
                    
                    var file_content: String;
                    do {
                        file_content = try String(contentsOfFile: velocity_json, encoding: .utf8)
                    } catch {
                        throw VelocityVMMError("Could not read VM definition: \(error)")
                    }
                    
                    let vm_info = try decoder.decode(VMProperties.self, from: Data(file_content.utf8))
                    NSLog("[Index] Found VM '\(vm_info.name)'.")
                    Manager.available_vms.append(vm_info)
                    
                }
            }
        } catch {
            throw VelocityVMMError("Could not index local storage: \(error)")
        }
    }
    
    //
    // Deploys a new bundle, registers the VM as an available_vm
    //
    static func create_vm(velocity_config: VelocityConfig, vm_properties: VMProperties) throws {
        do {
            try deploy_vm(velocity_config: velocity_config, vm_properties: vm_properties)
            self.available_vms.append(vm_properties)
        } catch {
            throw VelocityVMMError("VZError: \(error.localizedDescription)")
        }
    }
    
    //
    // Starts a given virtual machine by
    // name
    //
    static func start_vm(velocity_config: VelocityConfig, name: String) throws {
        NSLog("VM start request received for \(name).")
        if let _ =  get_running_vm_by_name(name: name) {
            throw VelocityVMMError("VZError: VM is already running!")
        }
        
        // Run in background thread because of the NSWindow
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                do {
                    let vm = try start_vm_by_name(velocity_config: velocity_config, vm_name: name)
                    Manager.running_vms.append(vm)
                } catch {
                    VLog("Could not start VirtualMachine.")
                }
            }
        }
    }
    
    //
    // Stop a VM by name
    //
    static func stop_vm(name: String) throws {
        NSLog("VM stop request received for \(name)")
        
        // Iterate with Index
        for (index, vm) in Manager.running_vms.enumerated() {
            if vm.virtual_machine.vm_info.name == name {
                // check if VM can shut down.
                if !vm.vz_virtual_machine.canRequestStop {
                    throw VelocityVMMError("Could not stop Virtual Machine.")
                }
                
                // Set VM State
                Manager.running_vms[index].virtual_machine.vm_state = VMState.SHUTTING_DOWN

                // Dispatch VM Stop to MainThread
                DispatchQueue.main.sync {
                    vm.vz_virtual_machine.stop { (result) in
                        VLog("Virtual Machine stopped.")
                        Manager.running_vms.remove(at: index)
                    }
                }
                return
            }
        }
        throw VelocityVMMError("Cannot stop VM that is not running.")
    }
    
    static func remove_vm() {
        
    }
    
    //
    // Get running vm by its name
    //
    static func get_running_vm_by_name(name: String) -> VirtualMachineExt? {
        for vm in Manager.running_vms {
            if vm.virtual_machine.vm_info.name == name {
                return vm;
            }
        }
        return nil;
    }
    
    //
    // Take a snapshot from given VM
    //
    static func screen_snapshot(vm: VirtualMachineExt) -> Data? {
        DispatchQueue.main.sync {
            let image = capture_hidden_window(windowNumber: vm.window_id)
            return image?.pngData
        }
    }
    
    
    static func vnc_for_vm() {
        
    }
    
}