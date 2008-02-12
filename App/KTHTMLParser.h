//
//  KTHTMLParser.h
//  KTComponents
//
//  Copyright (c) 2005-2006, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
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

#import <Foundation/Foundation.h>

#import "KTWebViewComponent.h"


@class KTDocument, KTHTMLParserMasterCache, KTMediaFileUpload, KTWebViewTextEditingBlock;


@interface KTHTMLParser : NSObject
{
	NSString				*myID;
	NSString				*myTemplate;
	id <KTWebViewComponent>	myComponent;
	KTHTMLParserMasterCache	*myCache;
	id						myDelegate;
	KTPage					*myCurrentPage;
	int						myHTMLGenerationPurpose;
	BOOL					myGenerateArchives;
	BOOL					myUseAbsoluteMediaPaths;
	KTHTMLParser			*myParentParser;	// Weak ref
	
	int myIfCount;
	
	NSIndexPath	*myForEachIndexes;
	NSIndexPath *myForEachCounts;
	
	KTDocument *myDocument;
}

+ (NSString *)HTMLStringWithTemplate:(NSString *)aTemplate component:(id <KTWebViewComponent>)component;

+ (NSString *)HTMLStringWithTemplate:(NSString *)aTemplate
						   component:(id <KTWebViewComponent>)component
			   useAbsoluteMediaPaths:(BOOL)useAbsoluteMediaPaths;

- (id)initWithTemplate:(NSString *)HTMLTemplate component:(id <KTWebViewComponent>)parsedComponent;
- (id)initWithPage:(KTPage *)page;	// Convenience method that parses the whole page

// Accessors
- (NSString *)parserID;
- (NSString *)templateHTML;
- (id <KTWebViewComponent>)component;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (KTPage *)currentPage;
- (void)setCurrentPage:(KTPage *)page;

- (int)HTMLGenerationPurpose;
- (void)setHTMLGenerationPurpose:(int)purpose;

- (BOOL)useAbsoluteMediaPaths;
- (void)setUseAbsoluteMediaPaths:(BOOL)flag;

- (BOOL)generateArchives;
- (void)setGenerateArchives:(int)gen;


- (KTHTMLParser *)parentParser;

// parsing
- (NSString *)parseTemplate;

@end


@interface NSObject (KTHTMLParserDelegate)
- (void)HTMLParser:(KTHTMLParser *)parser didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object;
- (void)HTMLParser:(KTHTMLParser *)parser didEncounterResourceFile:(NSString *)resourcePath;
- (void)HTMLParser:(KTHTMLParser *)parser didParseMediaFile:(KTAbstractMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;	
- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTWebViewTextEditingBlock *)textBlock;
@end
