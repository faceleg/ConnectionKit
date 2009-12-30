//
//  BadgePageletDelegate.m
//  Sandvox SDK
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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

#import "BadgePageletDelegate.h"


static NSArray *sBadgeNames = nil;
static NSArray *sAltStrings = nil;

@implementation BadgePageletDelegate

#pragma mark Dealloc

- (void)dealloc
{
	[self setBadgeAltString:nil];
	[self setBadgeTitleString:nil];
	[super dealloc];
}

#pragma mark Basic properties

+ (NSSet *)plugInKeys
{ 
    return [NSSet setWithObjects:@"badgeTypeTag", @"anonymous", @"openLinkInNewWindow", nil];
}

@synthesize badgeTypeTag = _badgeTypeTag;
@synthesize anonymous = _anonymous;
@synthesize openLinkInNewWindow = _openLinkInNewWindow;

#pragma mark Other

+ (NSArray *)sharedBadgeNames
{
	if (nil == sBadgeNames)
	{
		sBadgeNames = [[NSArray alloc] initWithObjects:
			@"sandvox_castle_white", 
			@"sandvox_castle_top", 
			@"sandvox_bucket_white",
			@"sandvox_bucket",
			@"sandvox_icon_white", nil];
	}
	return sBadgeNames;
}

// These are various strings, randomly chosen, for the blurb on the badge.  This will help direct
// Traffic to the Sandvox site!

+ (NSArray *)sharedAltStrings
{
	if (nil == sAltStrings)
	{
		sAltStrings = [[NSArray alloc] initWithObjects:
			LocalizedStringInThisBundle(@"The Website Builder for the Mac - publish blogs and photos on any host", @"Sandvox link-back blurb"),
			LocalizedStringInThisBundle(@"The easy mac web site creator - for school, family, business", @"Sandvox link-back blurb"),
			LocalizedStringInThisBundle(@"Create websites on the Mac and host them anywhere", @"Sandvox link-back blurb"),
			LocalizedStringInThisBundle(@"Build websites, photo albums, and blogs on the Mac", @"Sandvox link-back blurb"),
			LocalizedStringInThisBundle(@"Build and publish a web site with your Mac - for individuals, education, and small business", @"Sandvox link-back blurb"),
			LocalizedStringInThisBundle(@"Using your Macintosh, publish your photo album / blog / website on any ISP", @"Sandvox link-back blurb"),
			nil];
		// Changed 9 Oct 2008 to tweak the terms a bit, just so that the phrases used will be adjusted to mix things up a bit.
	}
	return sAltStrings;
}

- (void)setBadgeAltString:(NSString *)aBadgeAltString
{
    [aBadgeAltString retain];
    [_badgeAltString release];
    _badgeAltString = aBadgeAltString;
}

- (void)setBadgeTitleString:(NSString *)aBadgeTitleString
{
    [aBadgeTitleString retain];
    [_badgeTitleString release];
    _badgeTitleString = aBadgeTitleString;
}

- (NSString *) badgePreludeString
{
	return LocalizedStringInThisBundle(@"Created with", @"string that goes before badgeLinkString, for badge - always BEFORE 'Sandvox' regardless of language");
}

- (NSString *) badgeLinkString
{
	return LocalizedStringInThisBundle(@"Sandvox", @"linked text in the text badge linking back to sandvox site.  Always FOLLOWS the 'created with' regardless of language.");
}


// Use a hash to get a sort of arbitrary string for this unique document
- (NSString *) generateBlurbVariant:(int)aVariant
{
	NSString *seedString = [[self elementPlugInContainer] siteObjectIDURIRepresentationString];
	NSData *hashData = [[seedString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] SHA1HashDigest];
	unsigned char *bytes = (unsigned char *)[hashData bytes];
	// we have a nice 20-byte hash .... now to boil this down to a very small number!
	
	// Make a quick checksum of this
	unsigned long long total = 0;
	int i;
	for ( i = 0 ; i < 20 ; i++ )
	{
		unichar theChar = bytes[i];
		total = (total << 1) ^ theChar;
	}
	
	total += aVariant;		// Offset the number just a bit
	
	int stringNumber = total % [[BadgePageletDelegate sharedAltStrings] count];
	NSString *blurb = [[BadgePageletDelegate sharedAltStrings] objectAtIndex:stringNumber];

	return blurb;
	
}

- (NSString *) badgeAltString
{
	if (nil == _badgeAltString)
	{
		NSString *blurb = [self generateBlurbVariant:0];
		NSString *altString = [NSString stringWithFormat:LocalizedStringInThisBundle(@"Created with Sandvox - %@",@"Alt string for sandvox badge"), blurb];			
		[self setBadgeAltString:altString];
	}
	return _badgeAltString;		// don't want to calculate all the time.  Same for a document?
}

- (NSString *) badgeTitleString
{
	if (nil == _badgeTitleString)
	{
		NSString *blurb = [self generateBlurbVariant:1];
		NSString *titleString = [NSString stringWithFormat:LocalizedStringInThisBundle(@"Learn about Sandvox - %@",@"title string for sandvox badge link"), blurb];			
		[self setBadgeTitleString:titleString];
	}
	return _badgeTitleString;		// don't want to calculate all the time.  Same for a document?
}


// TAG 0 means not image...


- (NSString *)currentBadgeName
{
	NSString *result = nil;
	unsigned int tag = [self badgeTypeTag];
	if (tag >= 1 && tag <= [[BadgePageletDelegate sharedBadgeNames] count])
	{
		result = [[BadgePageletDelegate sharedBadgeNames] objectAtIndex:tag-1];
	}
	return result;
}

// Returns path of badge resource.  This is used by the template to get the path in resources directory
- (NSString *) badgeResourcePath
{
	NSString *path = [[self bundle] pathForImageResource:[self currentBadgeName]];
	return path;
}

// Called via recursiveComponentPerformSelector

- (void)addResourcesToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
	NSString *badgeName = [self currentBadgeName];
	if (nil != badgeName)
	{
		NSString *path = [[self bundle] pathForImageResource:badgeName];
        OBASSERT(path);
		[aSet addObject:path];
	}
}

- (IBAction)badgeClicked:(id)sender
{
	[self setBadgeTypeTag:[sender tag]];
}

@end
