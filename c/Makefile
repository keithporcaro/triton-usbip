CC=gcc
CFLAGS= -Wall -DLINUX
PROGS= hid-mouse hid-keyboard cdc-acm hid-triton

all:	${PROGS}

hid-mouse:	usbip.c hid-mouse.c
		${CC} ${CFLAGS} usbip.c -c
		${CC} ${CFLAGS} usbip.o hid-mouse.c -o hid-mouse

hid-keyboard:	usbip.c hid-keyboard.c
		${CC} ${CFLAGS} usbip.c -c
		${CC} ${CFLAGS} usbip.o hid-keyboard.c -o hid-keyboard

cdc-acm:	usbip.c cdc-acm.c
		${CC} ${CFLAGS} usbip.c -c
		${CC} ${CFLAGS} usbip.o cdc-acm.c -o cdc-acm

hid-triton:	usbip.c hid-triton.c triton_report.h triton_report_desc.h
		${CC} ${CFLAGS} usbip.c -c
		${CC} ${CFLAGS} usbip.o hid-triton.c -o hid-triton

test:	test_triton_report.c triton_report.h
		${CC} ${CFLAGS} test_triton_report.c -o test_triton_report
		./test_triton_report

clean:
		rm -f ${PROGS} test_triton_report core core.* *.o temp.* *.out typescript*
