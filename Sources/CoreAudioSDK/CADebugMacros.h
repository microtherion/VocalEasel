/*	Copyright: 	© Copyright 2005 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
			copyrights in this original Apple software (the "Apple Software"), to use,
			reproduce, modify and redistribute the Apple Software, with or without
			modifications, in source and/or binary forms; provided that if you redistribute
			the Apple Software in its entirety and without modifications, you must retain
			this notice and the following text and disclaimers in all such redistributions of
			the Apple Software.  Neither the name, trademarks, service marks or logos of
			Apple Computer, Inc. may be used to endorse or promote products derived from the
			Apple Software without specific prior written permission from Apple.  Except as
			expressly stated in this notice, no other rights or licenses, express or implied,
			are granted by Apple herein, including but not limited to any patent rights that
			may be infringed by your derivative works or by other works in which the Apple
			Software may be incorporated.

			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
			WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
			WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
			PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
			COMBINATION WITH YOUR PRODUCTS.

			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
			CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
			GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
			ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
			OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
			(INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
			ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/*=============================================================================
	CADebugMacros.h

	
	Revision 1.22  2006/01/17 22:13:07  dwyatt
	__LP64__ warnings
	
	Revision 1.21  2005/03/15 22:50:28  jcm10
	use DebugPrintfLineEnding so that syslog doesn't get filled with empty lines
	
	Revision 1.20  2004/10/27 01:28:08  jcm10
	add more FailIf macros
	
	Revision 1.19  2004/09/09 09:14:26  jcm10
	add a ThrowIf for Windows errors
	
	Revision 1.18  2004/08/25 02:26:26  jcm10
	always flush when using the side file
	
	Revision 1.17  2004/08/02 18:45:35  dwyatt
	add LogWarning
	
	Revision 1.16  2004/04/13 21:00:55  jcm10
	get rid of ThrowError
	
	Revision 1.15  2004/04/12 22:58:29  jcm10
	fix the macros that used 4CC's to not generate warnings in release builds
	
	Revision 1.14  2004/04/01 20:00:36  jcm10
	add Throw and clean up the ThrowIf macros
	
	Revision 1.13  2004/02/27 01:45:19  jcm10
	add ThrowError()
	
	Revision 1.12  2004/01/29 22:50:09  jcm10
	have AssertNoError print the error number as a 4 char code
	
	Revision 1.11  2003/08/29 04:13:55  jcm10
	show the time in milliseconds
	
	Revision 1.10  2003/07/04 23:56:26  jcm10
	add a few more DebugMessages
	
	Revision 1.9  2003/06/06 01:51:32  jcm10
	clean up some whitespace
	
	Revision 1.8  2002/12/14 23:59:58  jcm10
	CADebugger is now C compatible so it can be included in pre-compiled headers
	
	Revision 1.7  2002/10/02 21:01:40  jcm10
	add ThrowIfNULL
	
	Revision 1.6  2002/09/11 19:17:55  jcm10
	in ThrowIfError, print the error number as a four char code too
	
	Revision 1.5  2002/07/20 01:46:45  jcm10
	turn off thread stamping
	
	Revision 1.4  2002/07/17 21:53:08  jcm10
	make the thread stamping and time stamping work right
	
	Revision 1.3  2002/07/03 23:49:55  jcm10
	add AssertNoKernelError
	
	Revision 1.2  2002/05/02 22:31:57  jcm10
	display kernel errors in hex
	
	Revision 1.1  2002/03/01 01:52:40  jcm10
	moved here from ../Utility
	
	Revision 1.1  2002/02/28 23:18:54  jcm10
	added the CA prefix to the files for more consistency
	
	Revision 0.0  Thu Feb 28 2002 14:46:56 US/Pacific  moorf
	Created
		
	$NoKeywords: $
=============================================================================*/
#if !defined(__CADebugMacros_h__)
#define __CADebugMacros_h__

//=============================================================================
//	CADebugMacros
//=============================================================================

//#define	CoreAudio_StopOnFailure			1
//#define	CoreAudio_TimeStampMessages		1
//#define	CoreAudio_ThreadStampMessages	1
//#define	CoreAudio_FlushDebugMessages	1

#if __BIG_ENDIAN__
	#define	CA4CCToCString(the4CC)	{ ((char*)&the4CC)[0], ((char*)&the4CC)[1], ((char*)&the4CC)[2], ((char*)&the4CC)[3], 0 }
#else
	#define	CA4CCToCString(the4CC)	{ ((char*)&the4CC)[3], ((char*)&the4CC)[2], ((char*)&the4CC)[1], ((char*)&the4CC)[0], 0 }
#endif

#pragma mark	Basic Definitions

#if	DEBUG || CoreAudio_Debug
	
	// can be used to break into debugger immediately, also see CADebugger
	#define BusError()		(*(long *)0 = 0)
	
	//	basic debugging print routines
	#if	TARGET_OS_MAC && !TARGET_API_MAC_CARBON
		extern pascal void DebugStr(const unsigned char* debuggerMsg);
		#define	DebugMessage(msg)	DebugStr("\p"msg)
		#define DebugMessageN1(msg, N1)
		#define DebugMessageN2(msg, N1, N2)
		#define DebugMessageN3(msg, N1, N2, N3)
	#else
		#include "CADebugPrintf.h"
		
		#if	(CoreAudio_FlushDebugMessages && !CoreAudio_UseSysLog) || defined(CoreAudio_UseSideFile)
			#define	FlushRtn	;fflush(DebugPrintfFile)
		#else
			#define	FlushRtn
		#endif
		
		#if		CoreAudio_ThreadStampMessages
			#include <pthread.h>
			#include "CAHostTimeBase.h"
			#define	DebugMessage(msg)										DebugPrintfRtn(DebugPrintfFile, "%p %.4f: %s"DebugPrintfLineEnding, pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), msg) FlushRtn
			#define DebugMessageN1(msg, N1)									DebugPrintfRtn(DebugPrintfFile, "%p %.4f: "msg"\n", pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1) FlushRtn
			#define DebugMessageN2(msg, N1, N2)								DebugPrintfRtn(DebugPrintfFile, "%p %.4f: "msg"\n", pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2) FlushRtn
			#define DebugMessageN3(msg, N1, N2, N3)							DebugPrintfRtn(DebugPrintfFile, "%p %.4f: "msg"\n", pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3) FlushRtn
			#define DebugMessageN4(msg, N1, N2, N3, N4)						DebugPrintfRtn(DebugPrintfFile, "%p %.4f: "msg"\n", pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4) FlushRtn
			#define DebugMessageN5(msg, N1, N2, N3, N4, N5)					DebugPrintfRtn(DebugPrintfFile, "%p %.4f: "msg"\n", pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4, N5) FlushRtn
			#define DebugMessageN6(msg, N1, N2, N3, N4, N5, N6)				DebugPrintfRtn(DebugPrintfFile, "%p %.4f: "msg"\n", pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4, N5, N6) FlushRtn
			#define DebugMessageN7(msg, N1, N2, N3, N4, N5, N6, N7)			DebugPrintfRtn(DebugPrintfFile, "%p %.4f: "msg"\n", pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4, N5, N6, N7) FlushRtn
			#define DebugMessageN8(msg, N1, N2, N3, N4, N5, N6, N7, N8)		DebugPrintfRtn(DebugPrintfFile, "%p %.4f: "msg"\n", pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4, N5, N6, N7, N8) FlushRtn
			#define DebugMessageN9(msg, N1, N2, N3, N4, N5, N6, N7, N8, N9)	DebugPrintfRtn(DebugPrintfFile, "%p %.4f: "msg"\n", pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4, N5, N6, N7, N8, N9) FlushRtn
		#elif	CoreAudio_TimeStampMessages
			#include "CAHostTimeBase.h"
			#define	DebugMessage(msg)										DebugPrintfRtn(DebugPrintfFile, "%.4f: %s"DebugPrintfLineEnding, pthread_self(), ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), msg) FlushRtn
			#define DebugMessageN1(msg, N1)									DebugPrintfRtn(DebugPrintfFile, "%.4f: "msg DebugPrintfLineEnding, ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1) FlushRtn
			#define DebugMessageN2(msg, N1, N2)								DebugPrintfRtn(DebugPrintfFile, "%.4f: "msg DebugPrintfLineEnding, ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2) FlushRtn
			#define DebugMessageN3(msg, N1, N2, N3)							DebugPrintfRtn(DebugPrintfFile, "%.4f: "msg DebugPrintfLineEnding, ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3) FlushRtn
			#define DebugMessageN4(msg, N1, N2, N3, N4)						DebugPrintfRtn(DebugPrintfFile, "%.4f: "msg DebugPrintfLineEnding, ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4) FlushRtn
			#define DebugMessageN5(msg, N1, N2, N3, N4, N5)					DebugPrintfRtn(DebugPrintfFile, "%.4f: "msg DebugPrintfLineEnding, ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4, N5) FlushRtn
			#define DebugMessageN6(msg, N1, N2, N3, N4, N5, N6)				DebugPrintfRtn(DebugPrintfFile, "%.4f: "msg DebugPrintfLineEnding, ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4, N5, N6) FlushRtn
			#define DebugMessageN7(msg, N1, N2, N3, N4, N5, N6, N7)			DebugPrintfRtn(DebugPrintfFile, "%.4f: "msg DebugPrintfLineEnding, ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4, N5, N6, N7) FlushRtn
			#define DebugMessageN8(msg, N1, N2, N3, N4, N5, N6, N7, N8)		DebugPrintfRtn(DebugPrintfFile, "%.4f: "msg DebugPrintfLineEnding, ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4, N5, N6, N7, N8) FlushRtn
			#define DebugMessageN9(msg, N1, N2, N3, N4, N5, N6, N7, N8, N9)	DebugPrintfRtn(DebugPrintfFile, "%.4f: "msg DebugPrintfLineEnding, ((Float64)(CAHostTimeBase::GetCurrentTimeInNanos()) / 1000000.0), N1, N2, N3, N4, N5, N6, N7, N8, N9) FlushRtn
		#else
			#define	DebugMessage(msg)										DebugPrintfRtn(DebugPrintfFile, "%s"DebugPrintfLineEnding, msg) FlushRtn
			#define DebugMessageN1(msg, N1)									DebugPrintfRtn(DebugPrintfFile, msg DebugPrintfLineEnding, N1) FlushRtn
			#define DebugMessageN2(msg, N1, N2)								DebugPrintfRtn(DebugPrintfFile, msg DebugPrintfLineEnding, N1, N2) FlushRtn
			#define DebugMessageN3(msg, N1, N2, N3)							DebugPrintfRtn(DebugPrintfFile, msg DebugPrintfLineEnding, N1, N2, N3) FlushRtn
			#define DebugMessageN4(msg, N1, N2, N3, N4)						DebugPrintfRtn(DebugPrintfFile, msg DebugPrintfLineEnding, N1, N2, N3, N4) FlushRtn
			#define DebugMessageN5(msg, N1, N2, N3, N4, N5)					DebugPrintfRtn(DebugPrintfFile, msg DebugPrintfLineEnding, N1, N2, N3, N4, N5) FlushRtn
			#define DebugMessageN6(msg, N1, N2, N3, N4, N5, N6)				DebugPrintfRtn(DebugPrintfFile, msg DebugPrintfLineEnding, N1, N2, N3, N4, N5, N6) FlushRtn
			#define DebugMessageN7(msg, N1, N2, N3, N4, N5, N6, N7)			DebugPrintfRtn(DebugPrintfFile, msg DebugPrintfLineEnding, N1, N2, N3, N4, N5, N6, N7) FlushRtn
			#define DebugMessageN8(msg, N1, N2, N3, N4, N5, N6, N7, N8)		DebugPrintfRtn(DebugPrintfFile, msg DebugPrintfLineEnding, N1, N2, N3, N4, N5, N6, N7, N8) FlushRtn
			#define DebugMessageN9(msg, N1, N2, N3, N4, N5, N6, N7, N8, N9)	DebugPrintfRtn(DebugPrintfFile, msg DebugPrintfLineEnding, N1, N2, N3, N4, N5, N6, N7, N8, N9) FlushRtn
		#endif
	#endif
	void	DebugPrint(const char *fmt, ...);	// can be used like printf
	#define DEBUGPRINT(msg) DebugPrint msg		// have to double-parenthesize arglist (see Debugging.h)
	#if VERBOSE
		#define vprint(msg) DEBUGPRINT(msg)
	#else
		#define vprint(msg)
	#endif
	
	#if	CoreAudio_StopOnFailure
		#include "CADebugger.h"
		#define STOP	CADebuggerStop()
	#else
		#define	STOP
	#endif

#else
	#define	DebugMessage(msg)
	#define DebugMessageN1(msg, N1)
	#define DebugMessageN2(msg, N1, N2)
	#define DebugMessageN3(msg, N1, N2, N3)
	#define DebugMessageN4(msg, N1, N2, N3, N4)
	#define DebugMessageN5(msg, N1, N2, N3, N4, N5)
	#define DebugMessageN6(msg, N1, N2, N3, N4, N5, N6)
	#define DebugMessageN7(msg, N1, N2, N3, N4, N5, N6, N7)
	#define DebugMessageN8(msg, N1, N2, N3, N4, N5, N6, N7, N8)
	#define DebugMessageN9(msg, N1, N2, N3, N4, N5, N6, N7, N8, N9)
	#define DEBUGPRINT(msg)
	#define vprint(msg)
	#define	STOP
#endif

void	LogError(const char *fmt, ...);			// writes to syslog (and stderr if debugging)
void	LogWarning(const char *fmt, ...);		// writes to syslog (and stderr if debugging)

#if	DEBUG || CoreAudio_Debug

#pragma mark	Debug Macros

#define	Assert(inCondition, inMessage)													\
			if(!(inCondition))															\
			{																			\
				DebugMessage(inMessage);												\
				STOP;																	\
			}

#define	AssertNoError(inError, inMessage)												\
			{																			\
				SInt32 __Err = (inError);												\
				if(__Err != 0)															\
				{																		\
					char __4CC[5] = CA4CCToCString(__Err);								\
					DebugMessageN2(inMessage ", Error: %d (%s)", (int)__Err, __4CC);		\
					STOP;																\
				}																		\
			}

#define	AssertNoKernelError(inError, inMessage)											\
			{																			\
				unsigned int __Err = (unsigned int)(inError);							\
				if(__Err != 0)															\
				{																		\
					DebugMessageN1(inMessage ", Error: 0x%X", __Err);					\
					STOP;																\
				}																		\
			}

#define	FailIf(inCondition, inHandler, inMessage)										\
			if(inCondition)																\
			{																			\
				DebugMessage(inMessage);												\
				STOP;																	\
				goto inHandler;															\
			}

#define	FailWithAction(inCondition, inAction, inHandler, inMessage)						\
			if(inCondition)																\
			{																			\
				DebugMessage(inMessage);												\
				STOP;																	\
				{ inAction; }															\
				goto inHandler;															\
			}

#define	FailIfNULL(inPointer, inAction, inHandler, inMessage)							\
			if((inPointer) == NULL)														\
			{																			\
				DebugMessage(inMessage);												\
				STOP;																	\
				{ inAction; }															\
				goto inHandler;															\
			}

#define	FailIfKernelError(inKernelError, inException, inMessage)						\
			{																			\
				kern_return_t __Err = (inKernelError);									\
				if(__Err != 0)															\
				{																		\
					DebugMessageN1(inMessage ", Error: 0x%X", __Err);					\
					STOP;																\
					{ inAction; }														\
					goto inHandler;														\
				}																		\
			}

#define	FailIfError(inError, inException, inMessage)									\
			{																			\
				SInt32 __Err = (inError);												\
				if(__Err != 0)															\
				{																		\
					char __4CC[5] = CA4CCToCString(__Err);								\
					DebugMessageN2(inMessage ", Error: %ld (%s)", __Err, __4CC);		\
					STOP;																\
					{ inAction; }														\
					goto inHandler;														\
				}																		\
			}

#if defined(__cplusplus)

#define Throw(inException)  STOP; throw (inException)

#define	ThrowIf(inCondition, inException, inMessage)									\
			if(inCondition)																\
			{																			\
				DebugMessage(inMessage);												\
				Throw(inException);														\
			}

#define	ThrowIfNULL(inPointer, inException, inMessage)									\
			if((inPointer) == NULL)														\
			{																			\
				DebugMessage(inMessage);												\
				Throw(inException);														\
			}

#define	ThrowIfKernelError(inKernelError, inException, inMessage)						\
			{																			\
				kern_return_t __Err = (inKernelError);									\
				if(__Err != 0)															\
				{																		\
					DebugMessageN1(inMessage ", Error: 0x%X", __Err);					\
					Throw(inException);													\
				}																		\
			}

#define	ThrowIfError(inError, inException, inMessage)									\
			{																			\
				SInt32 __Err = (inError);												\
				if(__Err != 0)															\
				{																		\
					char __4CC[5] = CA4CCToCString(__Err);								\
					DebugMessageN2(inMessage ", Error: %d (%s)", (int)__Err, __4CC);		\
					Throw(inException);													\
				}																		\
			}

#if TARGET_OS_WIN32
#define	ThrowIfWinError(inError, inException, inMessage)								\
			{																			\
				HRESULT __Err = (inError);												\
				if(FAILED(__Err))														\
				{																		\
					DebugMessageN1(inMessage ", Error: 0x%X", __Err);					\
					Throw(inException);													\
				}																		\
			}
#endif

#define	SubclassResponsibility(inMethodName, inException)								\
			{																			\
				DebugMessage(inMethodName": Subclasses must implement this method");	\
				Throw(inException);														\
			}

#endif	//	defined(__cplusplus)

#else

#pragma mark	Release Macros

#define	Assert(inCondition, inMessage)													\
			if(!(inCondition))															\
			{																			\
				STOP;																	\
			}

#define	AssertNoError(inError, inMessage)												\
			{																			\
				SInt32 __Err = (inError);												\
				if(__Err != 0)															\
				{																		\
					STOP;																\
				}																		\
			}

#define	AssertNoKernelError(inError, inMessage)											\
			{																			\
				unsigned int __Err = (unsigned int)(inError);							\
				if(__Err != 0)															\
				{																		\
					STOP;																\
				}																		\
			}

#define	FailIf(inCondition, inHandler, inMessage)										\
			if(inCondition)																\
			{																			\
				STOP;																	\
				goto inHandler;															\
			}

#define	FailWithAction(inCondition, inAction, inHandler, inMessage)						\
			if(inCondition)																\
			{																			\
				STOP;																	\
				{ inAction; }															\
				goto inHandler;															\
			}

#define	FailIfNULL(inPointer, inAction, inHandler, inMessage)							\
			if((inPointer) == NULL)														\
			{																			\
				STOP;																	\
				{ inAction; }															\
				goto inHandler;															\
			}

#define	FailIfKernelError(inKernelError, inException, inMessage)						\
			if((inKernelError) != 0)													\
			{																			\
				STOP;																	\
				{ inAction; }															\
				goto inHandler;															\
			}

#define	FailIfError(inError, inException, inMessage)									\
			if((inError) != 0)															\
			{																			\
				STOP;																	\
				{ inAction; }															\
				goto inHandler;															\
			}

#if defined(__cplusplus)

#define Throw(inException)  STOP; throw (inException)

#define	ThrowIf(inCondition, inException, inMessage)									\
			if(inCondition)																\
			{																			\
				Throw(inException);														\
			}

#define	ThrowIfNULL(inPointer, inException, inMessage)									\
			if((inPointer) == NULL)														\
			{																			\
				Throw(inException);														\
			}

#define	ThrowIfKernelError(inKernelError, inException, inMessage)						\
			{																			\
				kern_return_t __Err = (inKernelError);									\
				if(__Err != 0)															\
				{																		\
					Throw(inException);													\
				}																		\
			}

#define	ThrowIfError(inError, inException, inMessage)									\
			{																			\
				SInt32 __Err = (inError);												\
				if(__Err != 0)															\
				{																		\
					Throw(inException);													\
				}																		\
			}

#if TARGET_OS_WIN32
#define	ThrowIfWinError(inError, inException, inMessage)								\
			{																			\
				HRESULT __Err = (inError);												\
				if(FAILED(__Err))														\
				{																		\
					Throw(inException);													\
				}																		\
			}
#endif

#define	SubclassResponsibility(inMethodName, inException)								\
			{																			\
				Throw(inException);														\
			}

#endif	//	defined(__cplusplus)

#endif  //  DEBUG || CoreAudio_Debug

#endif
