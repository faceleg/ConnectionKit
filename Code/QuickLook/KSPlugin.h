//
//  KSPlugin.h
//  SandvoxQuickLook
//
//  Created by Mike on 20/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KSPlugin : NSObject
{
	@private
	NSBundle *myBundle;
}

+ (id)pluginWithPath:(NSString *)path;
+ (id)pluginWithBundle:(NSBundle *)bundle;
+ (id)pluginWithIdentifier:(NSString *)identifier;

+ (NSArray *)pluginSearchPaths;
+ (KSPlugin *)preferredPlugin:(KSPlugin *)pluginA :(KSPlugin *)pluginB;

// designated initializer
- (id)initWithBundle:(NSBundle *)bundle;

//+ (void)registerPluginClass:(Class)pluginClass forType:(NSString *)UTI;	Implement soon

- (NSBundle *)bundle;
@end
