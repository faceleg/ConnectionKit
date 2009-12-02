//
//  NSArray+KTExtensions.h
//  Sandvox
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
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

#import <Cocoa/Cocoa.h>


@class KTPage;
@interface NSArray (KTExtensions)

// operations that assume all objects in array are KTPages

/*! returns only those pages that are not children of other pages in the array */
- (NSArray *)parentObjects;

/*! returns whether any object in the array is parent to aPage
 NB: this is not a sophisticated search, assumes parents
 and children are essentially in order */
- (BOOL)containsParentOfPage:(KTPage *)aPage;

@end
