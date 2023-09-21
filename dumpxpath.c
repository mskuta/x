// SPDX-License-Identifier: Unlicense

/* How to install (on Debian and derivatives):
 *   1. apt-get -y install libxml2-dev
 *   2. cc -I/usr/include/libxml2 -odumpxpath dumpxpath.c -lxml2
 *   3. install -D -s -t/usr/local/bin dumpxpath
 * How to use:
 *   wget -O- http://vimcasts.org/feeds/ogg.rss | dumpxpath /rss/channel/item/enclosure/@url | wget -i- -x
 */

#define _POSIX_C_SOURCE 2  // expose getopt() in glibc
#include <err.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>

#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xpath.h>

void showusage(FILE* stream) {
	extern char* __progname;
	char* basename;
	if ((basename = strrchr(__progname, '/')) == NULL)
		basename = __progname;
	else
		basename++;
	fprintf(stream,
	        "Usage:\n"
	        "  %s XPATHEXPRESSION\n"
	        "  %s -h\n"
	        "Options:\n"
	        "  -h  Produce this text.\n",
	        basename,
	        basename);
}

int main(int argc, char* argv[]) {
	enum { RC_SUCCESS, RC_FAILURE, RC_WRONGUSAGE, RC_EMPTYRESULT };
	bool wrongusage = false;
	int ch;
	while ((ch = getopt(argc, argv, "h")) != -1)
		switch (ch) {
			case 'h':
				showusage(stdout);
				return RC_SUCCESS;
			default:
				wrongusage = true;
		}
	argc -= optind;
	argv += optind;
	if (argc != 1)
		wrongusage = true;
	if (wrongusage) {
		showusage(stderr);
		return RC_WRONGUSAGE;
	}

	xmlXPathObjectPtr xpathobj;
	xmlXPathContextPtr xpathctx;
	xmlParserCtxtPtr parserctx;
	char buf[BUFSIZ];
	ssize_t buflen;
	buflen = read(STDIN_FILENO, buf, sizeof buf);
	if (buflen == -1)
		err(RC_FAILURE, NULL);
	if (buflen == 0)
		errx(RC_EMPTYRESULT, "No input given");
	parserctx = xmlCreatePushParserCtxt(NULL, NULL, buf, buflen, NULL);
	if (parserctx == NULL)
		errx(RC_FAILURE, "xmlCreatePushParserCtxt() failed");
	do {
		buflen = read(STDIN_FILENO, buf, sizeof buf);
		if (buflen == -1)
			err(RC_FAILURE, NULL);
		if (xmlParseChunk(parserctx, buf, buflen, 0) != 0)
			errx(RC_FAILURE, "xmlParseChunk() failed");
	} while (buflen > 0);
	xmlParseChunk(parserctx, buf, buflen, 1);  // buflen is 0 at this point
	xpathctx = xmlXPathNewContext(parserctx->myDoc);
	if (xpathctx == NULL)
		errx(RC_FAILURE, "xmlXPathNewContext() failed");
	xpathobj = xmlXPathEvalExpression((xmlChar*)argv[0], xpathctx);
	if (xpathobj == NULL)
		errx(RC_FAILURE, "xmlXPathEvalExpression() failed");
	if (xpathobj->nodesetval == NULL || xpathobj->nodesetval->nodeNr == 0)
		errx(RC_EMPTYRESULT, "No nodes found");
	for (int i = 0; i < xpathobj->nodesetval->nodeNr; i++) {
		const xmlChar* content = xmlNodeGetContent(xpathobj->nodesetval->nodeTab[i]);
		if (xmlStrlen(content) > 0)
			printf("%s\n", content);
	}
	return RC_SUCCESS;
}

// vim: ts=8 sts=0 sw=8 noet
