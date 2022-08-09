# cython: profile=False
from libc.stdlib cimport malloc, free

cdef (Node *) __new_node(size_t size) nogil:
    """ Dynamically allocate an Node struct with the given size. """
    cdef Node *node = <Node *> malloc(sizeof(Node))
    node.size = size
    node.data = <int *> malloc(size*sizeof(int))
    node.next_node = NULL
    return node

cdef void copy_array(const int *input_array, Node *node) nogil:
    """ Copy the input array's data into the node. """
    cdef:
        size_t i

    for i in range(node.size):
        node.data[i] = input_array[i]

cdef (char *) to_bytes(LinkedList *arrays, size_t *output_size) nogil:
    """ Serialize the list of 32-bit integer arrays as bytes. """
    cdef:
        Py_ssize_t size, length, i, j, k
        int x
        Node *node
        char *output

    # get the total size
    size = 0
    length = arrays.i
    node = arrays.head
    for i in range(length):
        size += node.size
        node = node.next_node
    # allocate contiguous data
    output_size[0] = size*sizeof(int)
    output = <char *> malloc(output_size[0])
    k = 0
    node = arrays.head
    for i in range(length):
        for j in range(<Py_ssize_t> node.size):
            x = node.data[j]
            output[k + 0] = (x >>  0) & 0xFF
            output[k + 1] = (x >>  8) & 0xFF
            output[k + 2] = (x >> 16) & 0xFF
            output[k + 3] = (x >> 24) & 0xFF
            k += 4
        node = node.next_node

    return output

# Singly linked list data structure with a bit of a lookahead buffer

cdef (LinkedList *) linkedlist_init(size_t node_size,
                                    Py_ssize_t buffer) nogil:
    """ Dynamically allocate an LinkedList struct with the given size. """
    cdef LinkedList *self = <LinkedList *> malloc(sizeof(LinkedList))
    self.node_size = node_size
    self.buffer = buffer
    self.size = 0
    self.i = -1
    self.head = NULL
    self.addr = NULL
    self.tail = NULL

    linkedlist_fill(self)
    return self

cdef void linkedlist_dealloc(LinkedList *self) nogil:
    """ Teardown to free associated explicitly allocated memory. """
    cdef:
        Node *node
        Node *next_node

    node = self.head
    while node != NULL:
        next_node = node.next_node
        free(node.data)
        free(node)
        node = next_node
    free(self)

cdef void linkedlist__add(LinkedList *self, size_t size) nogil:
    """ Add a node of the given size to the end of the linked list. """
    cdef:
        Node *node

    node = __new_node(size)
    if self.size == 0:
        self.head = node
        self.addr = node
    else:
        self.tail.next_node = node
    self.tail = node
    self.size += 1

cdef void linkedlist_fill(LinkedList *self) nogil:
    """ Fill the buffer with uninitialized nodes. """
    cdef:
        Py_ssize_t i

    for i in range(self.i + self.buffer - (<Py_ssize_t> self.size) + 1):
        linkedlist__add(self, self.node_size)

cdef (Node *) linkedlist_get(LinkedList *self, size_t size) nogil:
    """ Get the node corresponding to the last currently empty position. """
    cdef:
        Node *node

    node = self.addr
    # reached end of linked list, fallback to dynamically allocated memory
    if node == NULL:
        linkedlist__add(self, size)
        node = self.tail
    # not enough space, overwrite with dynamically allocated memory
    if node.size < size:
        node.data = <int *> malloc(size*sizeof(int))

    # update the size with the actual size
    node.size = size
    self.addr = node.next_node
    self.i += 1
    return node

