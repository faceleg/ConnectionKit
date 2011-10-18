//
//  NSImage+Amazon.m
//  AmazonSupport
//
//  Created by Mike on 06/05/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "NSImage+Amazon.h"

#import "AmazonECSOperation.h"


@interface NSImage ( KTComponentsHack )
+ (NSImage *)imageInBundle:(NSBundle *)bundle named:(NSString *)imageName;
@end


@implementation NSImage (Amazon)

+ (NSImage *)flagForAmazonStore:(AmazonStoreCountry)store
{
	NSImage *result = nil;
	NSString *filename = nil;
	
	switch (store)
	{
		case AmazonStoreUS:
			filename = @"us_flag.png";
			break;
		case AmazonStoreUK:
			filename = @"uk_flag.png";
			break;
		case AmazonStoreCanada:
			filename = @"canada_flag.png";
			break;
		case AmazonStoreFrance:
			filename = @"france_flag.png";
			break;
		case AmazonStoreGermany:
			filename = @"german_flag.png";
			break;
		case AmazonStoreJapan:
			filename = @"japan_flag.png";
			break;
		case AmazonStoreSpain:
			filename = @"spain_flag.png";
			break;
		case AmazonStoreItaly:
			filename = @"italy_flag.png";
			break;
		case AmazonStoreChina:
			filename = @"china_flag.png";
			break;
		case AmazonStoreUnknown:
			NSLog("No flag for unknown store.");
			break;
	}
	
	if (filename) {
		// this requires +imageInBundle:named: which is not in this project, test first
		if ( [NSImage respondsToSelector:@selector(imageInBundle:named:)] )
		{
			result = [NSImage imageInBundle:[NSBundle bundleForClass:[AmazonECSOperation class]]
									  named:filename];
		}
	}
	
	return result;
}

@end
