/*=========================================================================
 This file is part of the Horos Project (www.horosproject.org)
 
 Horos is free software: you can redistribute it and/or modify
 it under the terms of the GNU Lesser General Public License as published by
 the Free Software Foundation,  version 3 of the License.
 
 The Horos Project was based originally upon the OsiriX Project which at the time of
 the code fork was licensed as a LGPL project.  However, not all of the the source-code
 was properly documented and file headers were not all updated with the appropriate
 license terms. The Horos Project, originally was licensed under the  GNU GPL license.
 However, contributors to the software since that time have agreed to modify the license
 to the GNU LGPL in order to be conform to the changes previously made to the
 OsirX project.
 
 Horos is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY EXPRESS OR IMPLIED, INCLUDING ANY WARRANTY OF
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE OR USE.  See the
 GNU Lesser General Public License for more details.
 
 You should have received a copy of the GNU Lesser General Public License
 along with Horos.  If not, see http://www.gnu.org/licenses/lgpl.html
 
 Prior versions of this file were published by the OsiriX team pursuant to
 the below notice and licensing protocol.
 ============================================================================
 Program:   OsiriX
  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.
     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
 ============================================================================*/

#import "AsyncSocket.h"
#import "HTTPServer.h"
#import "HTTPConnection.h"


@implementation HTTPServer

/**
 * Standard Constructor.
 * Instantiates an HTTP server, but does not start it.
**/
- (id)init
{
	if((self = [super init]))
	{
		// Initialize underlying asynchronous tcp/ip socket
		asyncSocket = [[AsyncSocket alloc] initWithDelegate:self];
		
		// Use default connection class of HTTPConnection
		connectionClass = [HTTPConnection self];
		
		// Configure default values for bonjour service
		
		// Use a default port of 0
		// This will allow the kernel to automatically pick an open port for us
		port = 0;
		
		// Bonjour domain. Use the local domain by default
		[self setDomain: @"local."];
		
		// If using an empty string ("") for the service name when registering,
		// the system will automatically use the "Computer Name".
		// Passing in an empty string will also handle name conflicts
		// by automatically appending a digit to the end of the name.
		[self setName: @""];
		
		// Initialize an array to hold all the HTTP connections
		connections = [[NSMutableArray alloc] init];
		
		// And register for notifications of closed connections
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(connectionDidDie:)
													 name:HTTPConnectionDidDieNotification
												   object:nil];
	}
	return self;
}

/**
 * Standard Deconstructor.
 * Stops the server, and clients, and releases any resources connected with this instance.
**/
- (void)dealloc
{
	// Remove notification observer
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Stop the server if it's running
	[self stop];
	
	// Release all instance variables
	[documentRoot release];
	[netService release];
	[domain release];
	[name release];
	[type release];
	[txtRecordDictionary release];
	[asyncSocket release];
	[connections release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Configuration:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the delegate connected with this instance.
**/
- (id)delegate
{
	return delegate;
}

/**
 * Sets the delegate connected with this instance.
**/
- (void)setDelegate:(id)newDelegate
{
	delegate = newDelegate;
}

/**
 * The document root is filesystem root for the webserver.
 * Thus requests for /index.html will be referencing the index.html file within the document root directory.
 * All file requests are relative to this document root.
**/
- (NSURL *)documentRoot {
    return documentRoot;
}
- (void)setDocumentRoot:(NSURL *)value
{
    if(![documentRoot isEqual:value])
	{
        [documentRoot release];
        documentRoot = [value copy];
    }
}

/**
 * The connection class is the class that will be used to handle connections.
 * That is, when a new connection is created, an instance of this class will be intialized.
 * The default connection class is HTTPConnection.
 * If you use a different connection class, it is assumed that the class extends HTTPConnection
**/
- (Class)connectionClass {
    return connectionClass;
}
- (void)setConnectionClass:(Class)value
{
    connectionClass = value;
}

/**
 * Domain on which to broadcast this service via Bonjour.
 * The default domain is @"local".
**/
- (NSString *)domain {
    return domain;
}
- (void)setDomain:(NSString *)value
{
	if(![domain isEqualToString:value])
	{
		[domain release];
        domain = [value copy];
    }
}

/**
 * The type of service to publish via Bonjour.
 * No type is set by default, and one must be set in order for the service to be published.
**/
- (NSString *)type {
    return type;
}
- (void)setType:(NSString *)value
{
	if(![type isEqualToString:value])
	{
		[type release];
		type = [value copy];
    }
}

/**
 * The name to use for this service via Bonjour.
 * The default name is an empty string,
 * which should result in the published name being the host name of the computer.
**/
- (NSString *)name {
    return name;
}
- (NSString *)publishedName {
	return [netService name];
}
- (void)setName:(NSString *)value
{
	if(![name isEqualToString:value])
	{
        [name release];
        name = [value copy];
    }
}

/**
 * The port to listen for connections on.
 * By default this port is initially set to zero, which allows the kernel to pick an available port for us.
 * After the HTTP server has started, the port being used may be obtained by this method.
**/
- (UInt16)port {
    return port;
}
- (void)setPort:(UInt16)value {
    port = value;
}

/**
 * The extra data to use for this service via Bonjour.
**/
- (NSDictionary *)TXTRecordDictionary {
	return txtRecordDictionary;
}
- (void)setTXTRecordDictionary:(NSDictionary *)value
{
	if(![txtRecordDictionary isEqualToDictionary:value])
	{
		[txtRecordDictionary release];
		txtRecordDictionary = [value copy];
		
		// And update the txtRecord of the netService if it has already been published
		if(netService)
		{
			[netService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:txtRecordDictionary]];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Control:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)start:(NSError **)errPtr
{
	BOOL success = [asyncSocket acceptOnPort:port error:errPtr];
	
	if(success)
	{
		// Update our port number
		[self setPort:[asyncSocket localPort]];
		
		// Output console message for debugging purposes
		NSLog(@"Started HTTP server on port %hu", port);
		
		// We can only publish our bonjour service if a type has been set
		if(type != nil)
		{
			// Create the NSNetService with our basic parameters
			netService = [[NSNetService alloc] initWithDomain:domain type:type name:name port:port];
			
			[netService setDelegate:self];
			[netService publish];
			
			// Do not set the txtRecordDictionary prior to publishing!!!
			// This will cause the OS to crash!!!
			
			// Set the txtRecordDictionary if we have one
			if(txtRecordDictionary != nil)
			{
				[netService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:txtRecordDictionary]];
			}
		}
	}
	else
	{
		if(errPtr) NSLog(@"Failed to start HTTP Server: %@", *errPtr);
	}
	
	return success;
}

- (BOOL)stop
{
	// First stop publishing the service via bonjour
	if(netService)
	{
		[netService stop];
		[netService release];
		netService = nil;
	}
	
	// Now stop the asynchronouse tcp server
	// This will prevent it from accepting any more connections
	[asyncSocket disconnect];
	
	// Now stop all HTTP connections the server owns
	@synchronized(connections)
	{
		[connections removeAllObjects];
	}
	
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Status:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the number of clients that are currently connected to the server.
**/
- (uint)numberOfHTTPConnections
{
	uint result = 0;
	
	@synchronized(connections)
	{
		result = [connections count];
	}
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-(void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
	id newConnection = [[connectionClass alloc] initWithAsyncSocket:newSocket forServer:self];
	
	@synchronized(connections)
	{
		[connections addObject:newConnection];
	}
	[newConnection release];
}

/**
 * This method is automatically called when a notification of type HTTPConnectionDidDieNotification is posted.
 * It allows us to remove the connection from our array.
**/
- (void)connectionDidDie:(NSNotification *)notification
{
	// Note: This method is called on the thread/runloop that posted the notification
	
	@synchronized(connections)
	{
		[connections removeObject:[notification object]];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Bonjour Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called when our bonjour service has been successfully published.
 * This method does nothing but output a log message telling us about the published service.
**/
- (void)netServiceDidPublish:(NSNetService *)ns
{
	// Override me to do something here...
	
	NSLog(@"Bonjour Service Published: domain(%@) type(%@) name(%@)", [ns domain], [ns type], [ns name]);
}

/**
 * Called if our bonjour service failed to publish itself.
 * This method does nothing but output a log message telling us about the published service.
**/
- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
	// Override me to do something here...
	
	NSLog(@"Failed to Publish Service: domain(%@) type(%@) name(%@)", [ns domain], [ns type], [ns name]);
	NSLog(@"Error Dict: %@", errorDict);
}

@end
