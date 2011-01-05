//
//  KTPage+Paths.h
//  Sandvox
//
//  Copyright 2008-2011 Karelia Software. All rights reserved.
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

#import "KTPage.h"


typedef enum	//	Defines the 3 ways of linking to a collection:
{
	KTCollectionDirectoryPath,			//		collection
	KTCollectionHTMLDirectoryPath,		//		collection/
	KTCollectionIndexFilePath,			//		collection/index.html
    KTCollectionNotEvenACollection = -1 //      filename.html
}
KTCollectionPathStyle;


@class KTSite, KTMaster, SVSidebar, SVTitleBox;


@interface KTPage (Paths)

#pragma mark File Name

@property(nonatomic, copy, readwrite) NSString *fileName;

// Ask a collection if a child item can have a given filename. By supplying the item in question, if it's already a child, will be taken into account
- (BOOL)isFilenameAvailable:(NSString *)filename forItem:(SVSiteItem *)item;


#pragma mark Path Extension
@property(nonatomic, copy, readonly) NSString *pathExtension;
- (NSString *)defaultPathExtension;
- (NSArray *)availablePathExtensions;


#pragma mark Summat else
- (NSString *)indexFilename;
- (NSString *)indexFileName;
- (NSString *)archivesFilename;


#pragma mark Publishing
- (NSString *)uploadPath;


#pragma mark Custom
- (NSURL *)URLAsCollection:(BOOL)collection;


@end
