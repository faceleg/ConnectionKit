//
//  BadgePlugIn.m
//  BadgeElement
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
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

#import "BadgePlugIn.h"

#import "NSData+Karelia.h"


static NSArray *sBadgeNames = nil;
static NSArray *sBadgeSizes = nil;
static NSArray *sAltStrings = nil;


@implementation BadgePlugIn

- (void)dealloc
{
    self.badgeAltString = nil;
    self.badgeTitleString = nil;
	[super dealloc];
}

- (void)awakeFromNew;
{
    [super awakeFromNew];
    [self setShowsTitle:NO];
    [self setBadgeTypeTag:1];
    [self setIncludeReferralCode:YES];
}


#pragma mark -
#pragma mark SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"badgeTypeTag", 
            @"includeReferralCode", 
            @"openLinkInNewWindow",
            nil];
}


#pragma mark -
#pragma mark HTML Generation

+ (NSArray *)sharedBadgeNames
{
	if (nil == sBadgeNames)
	{
		sBadgeNames = [[NSArray alloc] initWithObjects:
					   @"sandvox_icon_white",
					   @"sandvox_castle", 
					   @"sandvox_castle_white", 
					   @"sandvox_castle_top", 
					   @"sandvox_castle_top_white", 
					   @"sandvox_bucket",
					   @"sandvox_bucket_white",
					   nil];
	}
	return sBadgeNames;
}

+ (NSArray *)sharedBadgeSizes
{
    if ( nil == sBadgeSizes )
    {
        sBadgeSizes = [[NSArray alloc] initWithObjects:
                       [NSValue valueWithSize:NSMakeSize(88., 31.)],
                       [NSValue valueWithSize:NSMakeSize(88., 45.)],
                       [NSValue valueWithSize:NSMakeSize(88., 45.)],
                       [NSValue valueWithSize:NSMakeSize(88., 44.)],
                       [NSValue valueWithSize:NSMakeSize(88., 44.)],
                       [NSValue valueWithSize:NSMakeSize(94., 47.)],
                       [NSValue valueWithSize:NSMakeSize(94., 47.)],
                       nil];
    }
    return sBadgeSizes;
}

// These are various strings, randomly chosen, for the blurb on the badge.  This will help direct
// Traffic to the Sandvox site!

+ (NSArray *)sharedAltStrings
{
	if (nil == sAltStrings)
	{
		sAltStrings = [[NSArray alloc] initWithObjects:
			SVLocalizedString(@"The Website Builder for the Mac - publish blogs and photos on any host", @"Sandvox link-back blurb"),
			SVLocalizedString(@"The easy mac web site creator - for school, family, business", @"Sandvox link-back blurb"),
			SVLocalizedString(@"Create websites on the Mac and host them anywhere", @"Sandvox link-back blurb"),
			SVLocalizedString(@"Build websites, photo albums, and blogs on the Mac", @"Sandvox link-back blurb"),
			SVLocalizedString(@"Build and publish a web site with your Mac - for individuals, education, and small business", @"Sandvox link-back blurb"),
			SVLocalizedString(@"Using your Macintosh, publish your photo album / blog / website on any ISP", @"Sandvox link-back blurb"),
			nil];
		// Changed 9 Oct 2008 to tweak the terms a bit, just so that the phrases used will be adjusted to mix things up a bit.
	}
	return sAltStrings;
}

- (NSString *)badgePreludeString
{
	return SVLocalizedString(@"Created with", @"string that goes before badgeLinkString, for badge - always BEFORE 'Sandvox' regardless of language");
}

- (NSString *)badgeLinkString
{
	return SVLocalizedString(@"Sandvox", @"linked text in the text badge linking back to sandvox site.  Always FOLLOWS the 'created with' regardless of language.");
}

// Use a hash to get a sort of arbitrary string for this unique document
- (NSString *)generateBlurbVariant:(NSInteger)aVariant
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    NSString *seedString = NSMakeCollectable(CFUUIDCreateString(NULL, uuid));
    CFRelease(uuid);
    
    
    NSData *hashData = [[seedString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] SHA1Digest];
    unsigned char *bytes = (unsigned char *)[hashData bytes];
    [seedString release];
    // we have a nice 20-byte hash .... now to boil this down to a very small number!
	
    // Make a quick checksum of this
    unsigned long long total = 0;
    NSInteger i;
    for ( i = 0 ; i < 20 ; i++ )
	{
		unichar theChar = bytes[i];
		total = (total << 1) ^ theChar;
	}
	
	total += aVariant;		// Offset the number just a bit
	
	NSInteger stringNumber = total % [[BadgePlugIn sharedAltStrings] count];
	NSString *blurb = [[BadgePlugIn sharedAltStrings] objectAtIndex:stringNumber];
    
	return blurb;
}

// returns title of graphic to display
- (NSString *)currentBadgeName
{
	NSString *result = nil;
	NSUInteger tag = [self badgeTypeTag]; // TAG 0 means not image...
	if (tag > BADGE_TEXT && tag <= [[BadgePlugIn sharedBadgeNames] count])
	{
		result = [[BadgePlugIn sharedBadgeNames] objectAtIndex:tag-1];
	}
	return result;
}

- (NSSize)currentBadgeSize
{
	NSSize result = NSZeroSize;
	NSUInteger tag = [self badgeTypeTag]; // TAG 0 means not image...
	if (tag > BADGE_TEXT && tag <= [[BadgePlugIn sharedBadgeNames] count])
	{
		result = [(NSValue *)[[BadgePlugIn sharedBadgeSizes] objectAtIndex:tag-1] sizeValue];
	}
	return result;
}

// returns relative URL for current badge, suitable for use in HTML template
// alternatively, in template, could do <img src="[[=writeBadgeSrc]]"…
- (NSString *)badgeURLString
{
    // find badge resource
    NSString *language = [[[self currentContext] page] language];
    NSString *resourcePath = [[NSBundle bundleForClass:[self class]] 
                              pathForImageResource:[self currentBadgeName] 
                              language:language];
    NSURL *resourceURL = [NSURL fileURLWithPath:resourcePath];
    
    // add resource to context
    NSURL *contextURL = [[self currentContext] addResourceWithURL:resourceURL];
    
    // generate relative string for template
    NSString *result = [[self currentContext] relativeStringFromURL:contextURL];    
    return result;
}

- (void)writeHTML:(id <SVPlugInContext>)context
{
    [super writeHTML:context];
    [context addDependencyForKeyPath:@"language" ofObject:[context page]];
}

- (NSUInteger)imgWidth
{
    return [self currentBadgeSize].width;
}

- (NSUInteger)imgHeight
{
    return [self currentBadgeSize].height;
}


#pragma mark -
#pragma mark Properties

- (NSString *)badgeAltString
{
	if (nil == _badgeAltString)
	{
		NSString *blurb = [self generateBlurbVariant:0];
		NSString *altString = [NSString stringWithFormat:SVLocalizedString(@"Created with Sandvox - %@",@"Alt string for sandvox badge"), blurb];			
		[self setBadgeAltString:altString];
	}
	return _badgeAltString;		// don't want to calculate all the time.  Same for a document?
}
@synthesize badgeAltString = _badgeAltString;

- (NSString *)badgeTitleString
{
	if (nil == _badgeTitleString)
	{
		NSString *blurb = [self generateBlurbVariant:1];
		NSString *titleString = [NSString stringWithFormat:SVLocalizedString(@"Learn about Sandvox - %@",@"title string for sandvox badge link"), blurb];			
		[self setBadgeTitleString:titleString];
	}
	return _badgeTitleString;		// don't want to calculate all the time.  Same for a document?
}
@synthesize badgeTitleString = _badgeTitleString;

@synthesize badgeTypeTag = _badgeTypeTag;
@synthesize includeReferralCode = _includeReferralCode;
@synthesize openLinkInNewWindow = _openLinkInNewWindow;
@end
