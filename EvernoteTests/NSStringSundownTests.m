//
//  NSStringSundownTests.m
//  Evernote
//
//  Created by Atsushi Nagase on 6/17/12.
//  Copyright (c) 2012 LittleApps Inc. All rights reserved.
//

#import "NSStringSundownTests.h"
#import "NSString+Sundown.h"

@implementation NSStringSundownTests

- (void)testRender1 {
  NSString *mkdn = @"![aa](http://mydomain.tld/path/to/image.jpg)";
  NSString *html = [mkdn sd_renderedStringWithRenderFlags:HTML_SKIP_HTML|HTML_ESCAPE|HTML_USE_XHTML];
  STAssertEqualObjects(@"<p><img src=\"http://mydomain.tld/path/to/image.jpg\" alt=\"aa\"/></p>\n", html, nil);
}

- (void)testRender2 {
  NSString *mkdn = @"----";
  NSString *html = [mkdn sd_renderedStringWithRenderFlags:HTML_SKIP_HTML|HTML_ESCAPE|HTML_USE_XHTML];
  STAssertEqualObjects(@"<hr/>\n", html, nil);
}

- (void)testRender3 {
  NSString *mkdn = @"<input type=\"text\">";
  NSString *html = [mkdn sd_renderedStringWithRenderFlags:HTML_SKIP_HTML|HTML_ESCAPE|HTML_USE_XHTML];
  STAssertEqualObjects(@"<p>&lt;input type=&quot;text&quot;&gt;</p>\n", html, nil);
}

- (void)testRender4 {
  NSString *mkdn = @"<input type=\"text\">";
  NSString *html = [mkdn sd_renderedStringWithRenderFlags:HTML_SKIP_HTML|HTML_USE_XHTML];
  STAssertEqualObjects(@"", html, nil);
}

@end
