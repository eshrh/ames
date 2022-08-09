cdef void copy_array(const int *input_array, Node *node) nogil
cdef (char *) to_bytes(LinkedList *arrays, size_t *output_size) nogil

# linked list

cdef struct Node:
    size_t size
    int *data
    Node *next_node

cdef struct LinkedList:
    size_t size, node_size
    Py_ssize_t i, buffer
    Node *head
    Node *addr
    Node *tail
    bint cleanup

cdef (LinkedList *) linkedlist_init(size_t node_size, Py_ssize_t buffer) nogil
cdef void linkedlist_dealloc(LinkedList *self) nogil

cdef void linkedlist_fill(LinkedList *self) nogil
cdef (Node *) linkedlist_get(LinkedList *self, size_t size) nogil

