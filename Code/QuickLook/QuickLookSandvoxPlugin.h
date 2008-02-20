//
//  QuickLookSandvoxPlugin.h
//  SandvoxQuickLook
//
//  Created by Mike on 20/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface QuickLookSandvoxPlugin : NSObject
{
	@private
	NSBundle *myBundle;
}

+ (id)pluginWithPath:(NSString *)path;
+ (id)pluginWithBundle:(NSBundle *)bundle;
+ (id)pluginWithIdentifier:(NSString *)identifier;

+ (NSArray *)pluginSearchPaths;
+ (QuickLookSandvoxPlugin *)preferredPlugin:(QuickLookSandvoxPlugin *)pluginA :(QuickLookSandvoxPlugin *)pluginB;

// designated initializer
- (id)initWithBundle:(NSBundle *)bundle;

//+ (void)registerPluginClass:(Class)pluginClass forType:(NSString *)UTI;	Implement soon

- (NSBundle *)bundle;
@end
