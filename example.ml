
int n = 0;

void func(int v) {
    n = n + 1;
    print('hello: ' + n + '-' + v + "\n");
}

func(3);
func(2);
func(1);
