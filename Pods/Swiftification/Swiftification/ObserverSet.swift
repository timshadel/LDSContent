//
// Original work Copyright (c) 2015, Michael Ash
// Modified work Copyright (c) 2016 Hilton Campbell
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of Michael Ash nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Dispatch

public class ObserverSetEntry<Parameters> {

    fileprivate weak var object: AnyObject?
    fileprivate let operationQueue: OperationQueue?
    fileprivate let f: (AnyObject) -> (Parameters) -> Void
    
    fileprivate init(object: AnyObject, operationQueue: OperationQueue?, f: @escaping (AnyObject) -> (Parameters) -> Void) {
        self.object = object
        self.operationQueue = operationQueue
        self.f = f
    }
    
}

public class ObserverSet<Parameters> {

    // Locking support
    
    fileprivate var queue = DispatchQueue(label: "com.mikeash.ObserverSet", attributes: [])
    
    fileprivate func synchronized(_ f: (Void) -> Void) {
        queue.sync(execute: f)
    }
    
    // Main implementation
    
    fileprivate var entries: [ObserverSetEntry<Parameters>] = []
    
    public init() {}
    
    /// Adds an observer `object`, whose method `f` will be called on notification. The method will be added to `queue` if supplied, otherwise it is run synchronously on the notifying thread.
    /// - Note: Because `object` is held weakly there may be no need to keep a reference to the returned
    /// observer set entry for explicit removal.
    /// - returns: an observer set entry which can be passed to `remove:` to stop observing
    @discardableResult
    public func add<T: AnyObject>(_ object: T, operationQueue: OperationQueue? = nil, _ f: @escaping (T) -> (Parameters) -> Void) -> ObserverSetEntry<Parameters> {
        let entry = ObserverSetEntry<Parameters>(object: object, operationQueue: operationQueue, f: { f($0 as! T) })
        synchronized {
            self.entries.append(entry)
        }
        return entry
    }
    
    /// Adds an observer `f` which will be called on notification. The method will be added to `queue` if supplied, otherwise it is run synchronously on the notifying thread.
    /// - returns: an observer set entry which should be passed to `remove:` to stop observing
    @discardableResult
    public func add(_ operationQueue: OperationQueue? = nil, _ f: @escaping (Parameters) -> Void) -> ObserverSetEntry<Parameters> {
        return self.add(self, operationQueue: operationQueue, { _ in f })
    }
    
    /// Removes an observer set entry.
    public func remove(_ entry: ObserverSetEntry<Parameters>) {
        synchronized {
            self.entries = self.entries.filter { $0 !== entry }
        }
    }
    
    /// Notifies current observers.
    public func notify(_ parameters: Parameters) {
        var toCall: [(OperationQueue?, (Parameters) -> Void)] = []
        
        synchronized {
            for entry in self.entries {
                if let object: AnyObject = entry.object {
                    toCall.append((entry.operationQueue, entry.f(object)))
                }
            }
            self.entries = self.entries.filter { $0.object != nil }
        }
        
        for (operationQueue, f) in toCall {
            if let operationQueue = operationQueue {
                operationQueue.addOperation(BlockOperation(block: {
                    f(parameters)
                }))
            } else {
                f(parameters)
            }
        }
    }
    
}

extension ObserverSet: CustomStringConvertible {
    
    public var description: String {
        var entries: [ObserverSetEntry<Parameters>] = []
        synchronized {
            entries = self.entries
        }
        
        let strings = entries.map {
            entry in
            (entry.object === self
                ? "\(entry.f)"
                : "\(entry.object) \(entry.f)")
        }
        let joined = strings.joined(separator: ", ")
        
        return "\(Mirror(reflecting: self)): (\(joined))"
    }

}
