typedef struct Node {
    int value;
    struct Node* next;
} Node;

Node* reverse(Node* head) {
    Node* prev = 0;
    Node* curr = head;
    while (curr) {
        Node* nextTemp = curr->next;
        curr->next = prev;
        prev = curr;
        curr = nextTemp;
    }
    return prev;
}

int main() {
    Node n1, n2, n3, n4, n5;
    n1.value = 10; n1.next = &n2;
    n2.value = 20; n2.next = &n3;
    n3.value = 30; n3.next = &n4;
    n4.value = 40; n4.next = &n5;
    n5.value = 50; n5.next = 0;
    
    Node* head = &n1;
    head = reverse(head);
    
    int correct = 1;
    int expected = 50;
    Node* curr = head;
    
    while (curr) {
        if (curr->value != expected) {
            correct = 0;
            break;
        }
        expected -= 10;
        curr = curr->next;
    }
    
    if (expected != 0) correct = 0;
    
    return correct ? 0xAA : 0xBB;
}
