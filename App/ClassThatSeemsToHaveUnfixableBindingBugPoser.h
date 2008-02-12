//
//  ClassThatSeemsToHaveUnfixableBindingBugPoser.h
//  Marvel
//
//  Created by Terrence Talbot on 4/22/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

// see thread: <http://www.cocoabuilder.com/archive/message/cocoa/2004/9/22/118021>
// this class is for debugging bindings, to see if something is misbound
// to something like File's Owner instead of an NSObjectController

// Usage: call poseAsClass as soon as possible in your app as follows
// [ClassThatSeemsToHaveUnfixableBindingBugPoser poseAsClass:[ClassThatSeemsToHaveUnfixableBindingBug class]];
// DON'T FORGET TO CHANGE THE CLASS YOU'RE INHERITING FROM/POSING AS BELOW

#import <Cocoa/Cocoa.h>

//typedef NSObject ClassThatSeemsToHaveUnfixableBindingBug;

@interface ClassThatSeemsToHaveUnfixableBindingBugPoser : NSObject 
{

}

@end
