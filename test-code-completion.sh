#!/bin/bash
# qwen2.5-coder:latest
# granite3-dense:2b
# llama3.2:latest
# starcoder2:15b
MODEL=${1:-granite3-dense:8b}

complete_code() {
    prefix="$1"
    suffix="$2"

    ollama run "$MODEL" <<- EOF
	/clear
	/set parameter seed 0
	/set parameter temperature 0
	/set parameter top_k 40
	/set parameter top_p .1
	/set nohistory
	/set system """
	You are a code assistant that completes missing code snippets.

	Given code with a missing section represented by \`|missing code here|\`, provide **only** the missing code that fits in that place.

	**Guidelines:**

	- Use variables, functions, and macros defined in the provided code when appropriate.
	- Do **not** otherwise use or reference functions that aren't defined in standard libraries.
	  (e.g, don't use a function called swap, if swap isn't defined in the context)
	- Do **not** include any parts of the existing code ([PREFIX] or [SUFFIX]) in your output.
	- Do **not** include any punctuation or keywords that are already present in the surrounding code.
	- Provide **only** the missing code, without any explanations or additional text.
        - This completion will be injected directly into an IDE editor buffer, so exclude code fences from output
	- Maintain the appropriate indentation level.

	**Examples:**

	---

	**Input Code:**

	int integer_to_char(int a) {
	    return |missing code here| + 0x30;
	}

	**Correct Output:**

	a

	---

	**Input Code:**

	int add(int a, int b) {
	    return |missing code here|;
	}

	**Correct Output:**

	a + b

	---

	**Input Code:**

	for (int i = 0; i < n; i++) {
	    sum += |missing code here|;
	}

	**Correct Output:**

	arr[i]

	---
	"""

        I'm now going to provide you some code with a missing snippet, that I would like you to complet would like you to complete.

	**Now, complete the following code:**

	$prefix|missing code here|$suffix

	- Do **not** include any parts of the existing code (\`${prefix}\` or \`${suffix}\`) in your output.
	- Provide **only** the missing code, without any explanations or additional text.

	**Your Output:**
	EOF
}

declare -A test_cases
index=0

test_case() {
    local prefix="$1"
    local expected="$2"
    local suffix="$3"

    test_cases[${index}_prefix]="$prefix"
    test_cases[${index}_expected]="$expected"
    test_cases[${index}_suffix]="$suffix"
    ((index++))
}

# Test Case 0
test_case '// Test Case 0: Convert numeral byte to integer
int to_integer(unsigned char numeral) {
    return (int) numeral - 0x' '30' ';
}'

# Test Case 1
test_case '// Test Case 1: Simple addition function
int add(int a, int b) {
    return ' 'a + b' ';
}'

# Test Case 2
test_case '// Test Case 2: Check if a number is prime
int is_prime(int n) {
    for (int i = 2; i < n; i++) {
        if (' 'n % i == 0' ') {
                return 0;
            }
        }
        return 1;
    }
}'

# Test Case 3
test_case '// Test Case 3: Calculate factorial recursively
int factorial(int n) {
    if (n <= 1) {
        return 1;
    } else {
        return ' 'n * factorial(n - 1)' ';
    }
}' 

# Test Case 4
test_case '// Test Case 4: Reverse a string in C
void reverse_string(char* str) {
    int n = strlen(str);
    for (int i = 0; i < n / 2; i++) {
        ' 'char temp = str[i];
        str[i] = str[n - i - 1];
        str[n - i - 1] = temp;' '
    }
}' 

# Test Case 5
test_case '# Test Case 5: Python function to calculate Fibonacci numbers
def fibonacci(n):
    if n <= 1:
        return n
    else:
        return ' 'fibonacci(n - 1) + fibonacci(n - 2);' ''

# Test Case 6
test_case '// Test Case 6: Sum elements in an array
int sum_array(int arr[], int n) {
    int sum = 0;
    for (int i = 0; i < n; i++) {
        sum += ' 'arr[i]' ';
    }
    return sum;
}' 

# Test Case 7
test_case '// Test Case 7: Swap two numbers using pointers
void swap(int* a, int* b) {
' '    int temp = *a;
    *a = *b;
    *b = temp;' '
}' 

# Test Case 8
test_case '// Test Case 8: C++ class method to calculate area of a circle
class Circle {
private:
    double radius;
public:
    Circle(double r) : radius(r) {}
    double area() {
        ' 'return 3.14159 * radius * radius;' '
    }
};' 

# Test Case 9
test_case '// Test Case 9: Check for palindrome in C
int is_palindrome(char* str) {
    int left = 0;
    int right = strlen(str) - 1;
    while (left < right) {
        if (str[left] != str[right]) {
            return 0;
        }
        ' '
	left++;
        right--;' '
    }
    return 1;
}' 

# Test Case 10
test_case '// Test Case 10: Find the maximum element in an array
int find_max(int arr[], int n) {
    int max = arr[0];
    for (int i = 1; i < n; i++) {
        if (' 'arr[i] > max' ') {
            max = arr[i];
        }
    }
    return max;
}' 

num_tests=$index

for ((i=0; i< num_tests; i++)); do
    echo "Running Test Case $i:"
    echo "----------------------------------------"
    prefix_var="${i}_prefix"
    expected_var="${i}_expected"
    suffix_var="${i}_suffix"
    prefix=${test_cases[$prefix_var]}
    expected=${test_cases[$expected_var]}
    suffix=${test_cases[$suffix_var]}
    
    output=$(complete_code "$prefix" "$suffix")

    [ $? != 0 ] && exit

    echo "Prefix:"
    echo "$prefix"
    echo -e "\nExpected Output:"
    echo "$expected"
    echo -e "\nSuffix:"
    echo "$suffix"
    echo -e "\nActual Output:"
    echo -ne '\e[1;32m'
    echo -ne "$prefix"
    echo -ne '\e[1;31m'
    echo -n "$output"
    echo -ne '\e[1;33m'
    echo -n "$suffix"
    echo -ne '\e[1;0m'
    echo -e "\n"
done

