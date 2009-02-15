//
//  SandvoxDesignPlugIn.m
//  SandvoxQuickLook
//
//  Created by Mike on 26/03/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "SandvoxDesignPlugIn.h"


@implementation SandvoxDesignPlugIn

+ (NSString *)pluginSubfolder
{
	return @"Designs";	// subfolder in App Support/APPNAME where this kind of plugin MAY reside.
}

+ (NSString *)applicationPluginPath	// Designs in their own top-level plugin dir
{
	return [[[KSPlugin applicationBundle] bundlePath] stringByAppendingPathComponent:@"Designs"];
}

/*	Register all known plugin types.
 */
+ (void)load
{
	[KSPlugin registerPluginClass:[self class] forFileExtension:@"svxDesign"];
	[KSPlugin registerPluginClass:[KSPlugin class] forFileExtension:@"svxElement"];
	[KSPlugin registerPluginClass:[KSPlugin class] forFileExtension:@"svxIndex"];
}

@end
