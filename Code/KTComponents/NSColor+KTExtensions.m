//
//  NSColor+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004 Biophony LLC. All rights reserved.
//

#import "NSColor+KTExtensions.h"


@implementation NSColor ( KTExtensions )



@end


@implementation NSColor ( HTML )

+ (NSColor *)linkColor
{
	return [NSColor colorWithCalibratedRed:0.1 green:0.1 blue:0.75 alpha:1.0];
}
/*"	returns empty string if can't convert.
"*/

- (NSString *)htmlString
{
	NSString *result = @"";
	
	NSColor *rgbColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	if (nil != rgbColor)
	{
		float red,green,blue,alpha;
		
		[rgbColor getRed:&red green:&green blue:&blue alpha:&alpha];
        
		int r = 0.5 + red	* 255.0;
		int g = 0.5 + green	* 255.0;
		int b = 0.5 + blue	* 255.0;
		result = [NSString stringWithFormat:@"#%02X%02X%02X",r,g,b];
        
		NSString *namedColor = [[NSColor colorDict] objectForKey:result];
		if (nil != namedColor)
		{
			result = namedColor;
		}
		else if ( (r/16 == r%16) && (g/16 == g%16) && (b/16 == b%16) )
		{
			result = [NSString stringWithFormat:@"#%X%X%X",r/16,g/16,b/16];
		}
	}
	return result;
}


static NSDictionary *sColorDict = nil;

+ (NSDictionary *)colorDict
{
	if (nil == sColorDict)
	{
		sColorDict = [[NSDictionary alloc] initWithObjectsAndKeys:
            
			// color name		// color hex code (as string
			@"white",			@"#FFFFFF",
			@"black",			@"#000000",
			@"silver",			@"#C0C0C0",
			@"gray",			@"#808080",
            
			// Pure colors
			@"red",				@"#FF0000",
			@"lime",			@"#00FF00",  // pure green
			@"blue",			@"#0000FF",
            
			// bright colors
			@"aqua",			@"#00FFFF",  // cyan
			@"fuchsia",			@"#FF00FF",  // violet
			@"yellow",			@"#FFFF00",
			
			// Medium colors
			@"teal",			@"#008080",
			@"purple",			@"#800080",
			@"olive",			@"#808000",
			
			@"maroon",			@"#800000",
			@"green",			@"#008000",
			@"navy",			@"#000080",
			
			nil];
	}
	return sColorDict;
}

@end
