//
//  APNEAContext.swift
//
//
//  Created by Pat Nakajima on 3/31/24.
//

import APNS
import Foundation
import Hummingbird
import Logging
import NIOCore

final class APNEAContext: RequestContext, @unchecked Sendable {
	/// core context
	public var coreContext: CoreRequestContext
	public var scheduler: PushScheduler!

	///  Initialize an `RequestContext`
	/// - Parameters:
	///   - allocator: Allocator
	///   - logger: Logger
	public init(channel: Channel, logger: Logger) {
		self.coreContext = .init(
			allocator: channel.allocator,
			logger: logger
		)
	}
}
