/* This is very specific module oriented to support fast text adding
 * for Symphero displaying engine. Helps a lot with template processing,
 * especially when template splits into thousands or even milions of
 * pieces.
 *
 * The idea is to have one long buffer that extends automatically and a
 * stack of positions in it that can be pushed/popped when application
 * need new portion of text.
 *
 * Andrew Maltsev, <amaltsev@valinux.com>, 2000
*/
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <string.h>

#define	MAX_STACK	200
#define	CHUNK_SIZE	1000

static char *buffer=NULL;
static unsigned long bufsize=0;
static unsigned long bufpos=0;
static unsigned long pstack[MAX_STACK];
static unsigned stacktop=0;

/************************************************************************/

MODULE = Symphero::PageSupport		PACKAGE = Symphero::PageSupport		

unsigned
level()
	CODE:
		RETVAL=stacktop;
	OUTPUT:
		RETVAL

void
reset()
	CODE:
		pstack[stacktop=0]=0;

void
push()
	CODE:
		if(stacktop+1>=MAX_STACK)
		 { fprintf(stderr,"Symphero::PageSupport - maximum stack deep reached!\n");
		   return;
                 }
		pstack[stacktop++]=bufpos;

char *
pop()
	CODE:
		RETVAL=NULL;
		if(!buffer)
		 { RETVAL="";
                 }
                else
		 { buffer[bufpos]=0;
                 }
                if(stacktop)
		 { bufpos=pstack[--stacktop];
                 }
                else
                 { bufpos=0;
                 }
		if(!RETVAL)
                 RETVAL=buffer+bufpos;
		/* fprintf(stderr,"level=%u results=%s\n",stacktop,RETVAL); */
	OUTPUT:
		RETVAL

void
addtext(text)
		char * text;
	CODE:
		if(text && *text)
                 { unsigned len=strlen(text);
	           if(bufpos+len >= bufsize)
                    { buffer=realloc(buffer,sizeof(*buffer)*(bufsize+=len+CHUNK_SIZE));
		      if(! buffer)
                       { fprintf(stderr,
                                 "Symphero::PageSupport - out of memory, length=%u, bufsize=%lu, bufpos=%lu\n",
                                 len,bufsize,bufpos);
                         return;
		       }
		    }
	           strcpy(buffer+bufpos,text);
	           bufpos+=len;
		 }
