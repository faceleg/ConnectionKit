//
//  DiggPlugIn.m
//  DiggElement
//
//  Copyright 2006-2010 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "DiggPlugIn.h"


typedef enum { diggTypePromoted, diggTypeSubmitted, diggTypeUser, diggTypeFriends } diggType;
typedef enum { diggHomepage, diggSubmitted, diggDugg, diggCommented } DiggUserOption;
typedef enum { DiggAllStories, DiggPopularStories, DiggUpcomingStories, DiggTopStories, DiggHotStories } DiggStoryPromotion;
typedef enum { digg5 = 0, digg10 = 2, digg15 = 4, digg20 = 6 } DeprecatedDiggNumberMask;


// LocalizedStringInThisBundle(@"Digg example no.", "String_On_Page_Template - followed by a number")


@interface DiggPlugIn ()
+ (NSString *)diggCategoryString:(NSString *)basis;
+ (NSString *)diggUserOptionString:(DiggUserOption)option;
@end


/*
 Plugin Properties we use:

diggType (see enum)  --> diggTypeString
diggUserOptions (see enum)  --> diggTypeString
diggUser  --> diggTypeString
maximumStories
diggDescriptions
diggCategory  (human readable version for popup) --> diggCategoryString
 */


@implementation DiggPlugIn

+ (NSSet *)plugInKeys
{ 
    return [NSSet setWithObjects:@"openLinksInNewWindow", nil];
}

#pragma mark -
#pragma mark Initialisation

+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Register value transformers
	NSSet *comparisonObjects = [NSSet setWithObjects:[NSNumber numberWithInt:diggTypeUser], [NSNumber numberWithInt:diggTypeFriends], nil];
	NSValueTransformer *transformer = [[KSContainsObjectValueTransformer alloc] initWithComparisonObjects:comparisonObjects];
	[NSValueTransformer setValueTransformer:transformer forName:@"DiggPageletTypeIsUserOrFriends"];
	[transformer release];
	
	comparisonObjects = [NSSet setWithObjects:[NSNumber numberWithInt:diggTypeSubmitted], [NSNumber numberWithInt:diggTypePromoted], nil];
	transformer = [[KSContainsObjectValueTransformer alloc] initWithComparisonObjects:comparisonObjects];
	[NSValueTransformer setValueTransformer:transformer forName:@"DiggPageletTypeIsSubmittedOrPromoted"];
	[transformer release];
	
	[pool release];
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	// Ensure our derived properties are up-to-date
	id pagelet = [self delegateOwner];  // was KTPagelet
	[pagelet setValue:[[self class] diggCategoryString:[pagelet valueForKey:@"diggCategory"]] forKey:@"diggCategoryString"];
	
	[pagelet setValue:[[self class] diggUserOptionString:[pagelet integerForKey:@"diggUserOptions"]]
			   forKey:@"diggUserOptionString"];
	
	
	// Old pagelets have to be converted to storing their story count in the new manner
	if (!isNewlyCreatedObject)
	{
		if (![[self delegateOwner] valueForKey:@"maximumStories"])
		{
			unsigned maxStories = 10;
			switch([[self delegateOwner] integerForKey:@"diggNumberMask"])
			{
				case digg5:
					maxStories = 5;
					break;
				case digg10:
					maxStories = 10;
					break;
				case digg15:
					maxStories = 15;
					break;
				case digg20:
					maxStories = 20;
					break;
			}
			[[self delegateOwner] setInteger:maxStories forKey:@"maximumStories"];
		}
	}
}

#pragma mark -
#pragma mark HTML Generation

+ (NSString *)diggUserOptionString:(DiggUserOption)option
{
	NSArray *types = [NSArray arrayWithObjects:@"popular", @"submissions", @"dugg", @"commented", nil];
	NSString *result = [types objectAtIndex:option];
	return result;
}

+ (NSString *)diggStoryPromotionString:(DiggStoryPromotion)story
{
	NSString *result;
	switch (story)
	{
		case DiggPopularStories:
			result = @"popular";
			break;
		case DiggUpcomingStories:
			result = @"upcoming";
			break;
		case DiggTopStories:
			result = @"top";
			break;
		case DiggHotStories:
			result = @"hot";
			break;
		default:
			result = nil;
			break;
	}
	return result;
}

+ (NSString *)diggCategoryString:(NSString *)basis
{
	NSString *result = nil;
    
    if (basis)
    {
        // Sanitize the string
        basis = [basis lowercaseString];
        if ([basis isEqualToString:@"political news"]) basis = @"politics";
        
        NSMutableString *buffer = [NSMutableString stringWithString:basis];
        
        [buffer replace:@"." with:@""];
        [buffer replace:@" & " with:@"_"];	// Convert " & " with a simple underscore
        [buffer replace:@" " with:@"_"];
        [buffer replace:@"/" with:@"_"];
        
        if ([buffer hasPrefix:@"all"])
        {
            buffer = nil;	/// New Digg API does not accept "all" as a parameter
        }
        
        result = [[buffer copy] autorelease];
        
        //[buffer stringByRemovingCharactersNotInSet:[NSCharacterSet alphanumericASCIICharacterSet]];
    }
    
	return result;
}

- (BOOL)diggCategoryIsTopic
{
	static NSSet *containers;
	if (!containers)
	{
		containers = [[NSSet alloc] initWithObjects:@"Technology",
													@"Science",
													@"World & Business",
													@"Sports",
													@"Entertainment",
													@"Gaming",
													@"Lifestyle",
													@"Offbeat",
													@"News",
													@"Videos",
													@"Images", nil];
	}
	
	NSString *diggCategory = [[self delegateOwner] valueForKey:@"diggCategory"];
	BOOL result = ![containers containsObject:diggCategory];
	return result;
}

/*	When the user changes a property in the GUI, we also need to change the corresponding HTML in the plugin
 */
- (void)plugin:(id)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue;
{
	if ([key isEqualToString:@"diggCategory"])
	{
		[plugin setValue:[[self class] diggCategoryString:value] forKey:@"diggCategoryString"];
	}
	else if ([key isEqualToString:@"diggUserOptions"])
	{
		[plugin setValue:[[self class] diggUserOptionString:[value intValue]] forKey:@"diggUserOptionString"];
	}
	else if ([key isEqualToString:@"diggStoryPromotion"])
	{
		[plugin setValue:[[self class] diggStoryPromotionString:[value intValue]] forKey:@"diggStoryPromotionString"];
	}
}


#pragma mark -
#pragma mark Inspector

+ (Class)inspectorViewControllerClass { return [DiggInspector class]; }


#pragma mark -
#pragma mark Properties

@synthesize openLinksInNewWindow = _openLinksInNewWindow;
@end
