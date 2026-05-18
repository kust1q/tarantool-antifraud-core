CC = gcc
CFLAGS = -O2 -fPIC -Wall
# Try to find tarantool headers
INCLUDES = -I/usr/include/tarantool -I/usr/local/include/tarantool -I/usr/include/lua5.1
LDFLAGS = -shared

all: fraud_utils.so

fraud_utils.so: fraud_utils.c
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) fraud_utils.c -o fraud_utils.so

clean:
	rm -f fraud_utils.so
