//
//  KTApplication.m
//  Marvel
//
//  Created by Terrence Talbot on 10/2/04.
//  Copyright 2004 Biophony, LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Override methods to clean up when we exit

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	Subclass NSApplication

IMPLEMENTATION NOTES & CAUTIONS:
	x

TO DO:
	Catch exceptions and report them better

 */

#import "KTApplication.h"
#import "KTAppDelegate.h"


@implementation KTApplication

// iMedia Browser Requirement

+ (NSString *)applicationIdentifier
{
	return @"com.karelia.Sandvox";
}

@end

