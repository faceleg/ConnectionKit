//
//  DiggPageletDelegate.m
//  DiggPagelet
//
//  Copyright (c) 2006, Karelia Software. All rights reserved.
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

#import "DiggPageletDelegate.h"
#import <KTComponents.h>
#import <ContainsValueTransformer.h>


// LocalizedStringInThisBundle(@"Digg example no.", "String_On_Page_Template - followed by a number")

@implementation DiggPageletDelegate

/*
 Plugin Properties we use:

diggType (see enum)  --> diggTypeString
diggUserOptions (see enum)  --> diggTypeString
diggUser  --> diggTypeString
diggNumberMask --> diggMaskString
diggDescriptions --> diggMaskString
diggCategory  (human readable version for popup) --> diggCategoryString

 
 */

typedef enum { diggTypePromoted, diggTypeSubmitted, diggTypeUser, diggTypeFriends } diggType;
typedef enum { diggHomepage, diggSubmitted, diggDugg, diggCommented } diggUserOptions;
typedef enum { digg5 = 0, digg10 = 2, digg15 = 4, digg20 = 6 } diggNumberMask;


#pragma mark -
#pragma mark HTML Generation

- (NSString *)diggMaskString
{
	int mask = [[self delegateOwner] integerForKey:@"diggNumberMask"];
	if (![[self delegateOwner] boolForKey:@"diggDescriptions"])
	{
		mask++;	// add one if NOT showing descriptions
	}
	return [NSString stringWithFormat:@"%u", mask];
}

// TODO: handle your friends' diggs

- (NSString *)diggTypeString
{
	NSArray *stringArray = [NSArray arrayWithObjects:
		@"front", @"submitted", @"user", @"___TODO___", nil];
	int theDiggType = [[self delegateOwner] integerForKey:@"diggType"];
	NSString *result = [stringArray objectAtIndex:theDiggType];
	
	if (diggTypeUser == theDiggType)
	{
		NSString *diggUser = [[self delegateOwner] valueForKey:@"diggUser"];
		if (nil == diggUser)
		{
			diggUser = @"";
		}
		NSArray *stringArray = [NSArray arrayWithObjects:
			@"homepage", @"submitted", @"dugg", @"commented", nil];
		int theUserOption = [[self delegateOwner] integerForKey:@"diggUserOptions"];
		NSString *diggUserOptionString = [stringArray objectAtIndex:theUserOption];
		result = [NSString stringWithFormat:@"%@/%@/%@",
						result,
						diggUserOptionString,
						diggUser];
	}
	else if (diggTypeFriends == theDiggType)
	{
		NSString *diggUser = [[self delegateOwner] valueForKey:@"diggUser"];
		if (nil == diggUser)
		{
			diggUser = @"";
		}
		result = [NSString stringWithFormat:@"%@/%@",
			result,
			diggUser];
	}
	return result;
}

- (NSString *)diggCategoryString
{
	NSString *result = [[[self delegateOwner] valueForKey:@"diggCategory"] lowercaseString];
	if ((nil == result) || [result hasPrefix:@"all"])
	{
		 result = @"all";
	}
	result = [result stringByReplacing:@"/" with:@"_"];	// for linux/unix
	return result;
}

#pragma mark -
#pragma mark Other

- (IBAction) openDigg:(id)sender
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://www.digg.com/"]];
}

+ (void) initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Register value transformers
	NSSet *comparisonObjects = [NSSet setWithObjects:[NSNumber numberWithInt:diggTypeUser], [NSNumber numberWithInt:diggTypeFriends], nil];
	NSValueTransformer *transformer = [[ContainsValueTransformer alloc] initWithComparisonObjects:comparisonObjects];
	[NSValueTransformer setValueTransformer:transformer forName:@"DiggPageletTypeIsUserOrFriends"];
	[transformer release];
	
	comparisonObjects = [NSSet setWithObjects:[NSNumber numberWithInt:diggTypeSubmitted], [NSNumber numberWithInt:diggTypePromoted], nil];
	transformer = [[ContainsValueTransformer alloc] initWithComparisonObjects:comparisonObjects];
	[NSValueTransformer setValueTransformer:transformer forName:@"DiggPageletTypeIsSubmittedOrPromoted"];
	[transformer release];
	
	[pool release];
}


@end
