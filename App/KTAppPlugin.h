//
//  KTAppPlugin.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTAppPlugin : NSObject
{
	@private
	NSBundle *myBundle;
}

+ (id)pluginWithPath:(NSString *)path;
+ (id)pluginWithBundle:(NSBundle *)bundle;
+ (id)pluginWithIdentifier:(NSString *)identifier;

+ (Class)registeredPluginClassForFileExtension:(NSString *)extension;
+ (void)registerPluginClass:(Class)pluginClass forFileExtension:(NSString *)extension;
//+ (void)registerPluginClass:(Class)pluginClass forType:(NSString *)UTI;	Implement soon

// designated initializer
- (id)initWithBundle:(NSBundle *)bundle;

- (NSBundle *)bundle;
- (NSString *)pluginType;
- (NSString *)version;
- (NSString *)identifier;
- (NSString *)minimumAppVersion;

- (id)pluginPropertyForKey:(NSString *)key;
- (id)defaultPluginPropertyForKey:(NSString *)key;

@end
