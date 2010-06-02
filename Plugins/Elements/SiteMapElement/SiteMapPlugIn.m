//
//  SiteMapPlugIn.m
//  Sandvox SDK: SiteMapElement
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

//  NOTE: No LocalizedStrings in this plugin, so no genstrings build phase needed


#import "SiteMapPlugIn.h"


@implementation SiteMapPlugIn

#pragma mark -
#pragma mark SVPlugIn

+ (NSSet *)plugInKeys
{ 
    return [NSSet setWithObjects:
            @"compact", 
            @"sections", 
            @"showHome", 
            @"showSiteMap",
            nil];
}


#pragma mark -
#pragma mark Initialization

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    
    // set initial properties //FIXME: or do we leave this to KTPluginInitialProperties?
    self.compact = NO;
    self.sections = NO;
    self.showHome = YES;
    self.showSiteMap = YES; //FIXME: what is this property for?
}


#pragma mark -
#pragma mark HTML Generation

- (BOOL)canCompactChildren:(NSArray *)children
{
    // if any children have children, return NO
    for ( id<SVPage> page in children )
    {
        if ( [[page childPages] count] )
        {
            return NO;
        }
    }
    
    return YES;
}

- (void)writeLinkOfPage:(id<SVPage>)aPage
              toContext:(id<SVPlugInContext>)context
{
    NSString *title = ([aPage title] ? [aPage title] : @"");
    if ( [aPage isEqual:[context page]] ) // not likely but maybe possible
    {
        // just emit title
        [[context HTMLWriter] writeText:title];
    }
    else
    {
        //FIXME: special case for LinkPage, add target=_BLANK if LinkPage and newWindowLink ???
        // emit href + title
        NSString *path = [context relativeURLStringOfPage:aPage];
        if (!path) path = @"";  // Happens for a site with no -siteURL set yet
        [[context HTMLWriter] startAnchorElementWithHref:path 
                                                   title:title
                                                  target:nil
                                                     rel:nil];
        [[context HTMLWriter] writeText:title];
        [[context HTMLWriter] endElement];            
    }
}

- (void)writeMapOfPage:(id<SVPage>)aPage
             toContext:(id<SVPlugInContext>)context
             asSection:(BOOL)asSection
          wantsCompact:(BOOL)wantsCompact
{	
    if ( [aPage includeInSiteMaps] ) // we must check this since we're recursive
	{
        // observe observable keypaths for aPage
        id<NSFastEnumeration> keyPaths = [aPage automaticRearrangementKeyPaths];
        for ( NSString *keyPath in keyPaths )
        {
            //FIXME: 75490: replace NOT watching title of thisPage with a DOM controller
            if ( [aPage isEqual:[context page]] && [keyPath isEqualToString:@"title"] ) continue;
            [(SVHTMLContext *)context addDependencyOnObject:aPage keyPath:keyPath];
        }
        
        // figure out what children, if any, should be included        
		NSMutableArray *children = [NSMutableArray array];
        for ( id<SVPage> childPage in [aPage childPages] )
        {
            if ( [childPage includeInSiteMaps] ) [children addObject:childPage];
        }
            
        // if asSection emit <h3>, else emit <li>
        [[context HTMLWriter] startElement:(asSection ? @"h3" : @"li") attributes:nil];
        
        // process aPage
        [self writeLinkOfPage:aPage toContext:context];
        
        // close h3
		if ( asSection ) [[context HTMLWriter] endElement];
		
        // process children
		if ( [children count] )
		{
            if ( wantsCompact && [self canCompactChildren:children] )
            {
                // show children inline , no recursion
                [[context HTMLWriter] startElement:@"ul" attributes:nil];
                [[context HTMLWriter] startElement:@"li" attributes:nil];
                
                BOOL firstChild = YES;
                for ( id<SVPage> child in children )
                {
                    [self writeLinkOfPage:child toContext:context];
                    // on the 2nd pass, emit \n&middot;
                    if ( !firstChild ) [[context HTMLWriter] writeHTMLString:@"&middot;"];
                    firstChild = NO;
                }
                
                [[context HTMLWriter] endElement]; // </li>
                [[context HTMLWriter] endElement]; // </ul>
            }
            else
            {
                // a simple list of children, processed recursively
                [[context HTMLWriter] startElement:@"ul" attributes:nil];

                for ( id<SVPage> child in children )
                {
                    [self writeMapOfPage:child 
                               toContext:context
                               asSection:NO // children can't be sections
                            wantsCompact:wantsCompact];
                }
                
                [[context HTMLWriter] endElement]; // </ul>
            }
        }
            
        // close li
        if ( !asSection ) [[context HTMLWriter] endElement];
    }
}

- (void)writeInnerHTML:(id <SVPlugInContext>)context
{
	id<SVPage> thisPage = (id<SVPage>)[context page];
    if ( thisPage ) // only generate a map if the context has a page
    {
        id<SVPage> rootPage = [thisPage rootPage];
        OBASSERT(rootPage);
        
        // add our dependencies manually since we have no template for the parser to handle this for us
        [context addDependencyForKeyPath:@"compact" ofObject:self];
        [context addDependencyForKeyPath:@"sections" ofObject:self];
        [context addDependencyForKeyPath:@"showHome" ofObject:self];
        
        // map root page
        if ( self.showHome )
        {
            // Note: if site map IS home, it will still be shown regardless of show site map checkbox
            
            [[context HTMLWriter] startElement:(self.sections ? @"h3" : @"p") attributes:nil];
            [self writeLinkOfPage:rootPage toContext:context];
            [[context HTMLWriter] endElement];
            
            // observe root's observable keypaths
            id<NSFastEnumeration> keyPaths = [rootPage automaticRearrangementKeyPaths];
            for ( NSString *keyPath in keyPaths )
            {
                //FIXME: 75490: replace NOT watching title of thisPage with a DOM controller
                if ( [thisPage isEqual:rootPage] && [keyPath isEqualToString:@"title"] ) continue;
                [(SVHTMLContext *)context addDependencyOnObject:rootPage keyPath:keyPath];
            }
        }
        
        // recursively map each top-level page        
        NSArray *topLevelPages = [rootPage childPages];
        if ( topLevelPages.count > 0 )
        {
            if ( !self.sections ) [[context HTMLWriter] startElement:@"ul" attributes:nil];
            
            for ( id<SVPage> page in topLevelPages )
            {
                [self writeMapOfPage:page
                           toContext:context
                           asSection:self.sections
                        wantsCompact:self.compact];
            }
            
            if ( !self.sections ) [[context HTMLWriter] endElement];
        }
    }
}


#pragma mark -
#pragma mark Properties

@synthesize compact = _compact;
@synthesize sections = _sections;
@synthesize showHome = _showHome;
@synthesize showSiteMap = _showSiteMap;
@end
