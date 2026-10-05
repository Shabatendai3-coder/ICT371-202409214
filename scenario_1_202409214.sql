-- SCENARIO 1: University Library Book Loans
DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;

-- 1. CREATE TABLES
CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100),
    available_copies INT
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    student_number VARCHAR(20),
    book_id INT REFERENCES books(book_id),
    quantity INT,
    status VARCHAR(20) DEFAULT 'Borrowed'
);

INSERT INTO books (title, available_copies) VALUES
('Database Systems', 10),
('Operating Systems', 2),
('Networking Basics', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE copies INT;
BEGIN
    SELECT available_copies INTO copies FROM books WHERE book_id = 3;
    IF copies = 0 THEN
        RAISE NOTICE 'Book ID 3 is UNAVAILABLE';
    ELSIF copies < 5 THEN
        RAISE NOTICE 'Book ID 3 is LOW on copies: %', copies;
    ELSE
        RAISE NOTICE 'Book ID 3 is SUFFICIENTLY stocked: %', copies;
    END IF;
END $$;

-- 3. WHILE and FOR
DO $$
DECLARE i INT := 1;
BEGIN
    RAISE NOTICE '--- Overdue Reminders (WHILE) ---';
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Overdue Reminder %', i;
        i := i + 1;
    END LOOP;
    RAISE NOTICE '--- Shelf Numbers (FOR) ---';
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Checking shelf number %', i;
    END LOOP;
END $$;

-- 4. borrow_book PROCEDURE
CREATE OR REPLACE PROCEDURE borrow_book(p_student VARCHAR, p_book_id INT, p_qty INT)
LANGUAGE plpgsql AS $$
DECLARE v_avail INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %', p_qty;
    END IF;
    SELECT available_copies INTO v_avail FROM books WHERE book_id = p_book_id;
    IF v_avail IS NULL THEN
        RAISE NOTICE 'Book % not found', p_book_id;
    ELSIF v_avail >= p_qty THEN
        UPDATE books SET available_copies = available_copies - p_qty WHERE book_id = p_book_id;
        INSERT INTO book_loans(student_number, book_id, quantity, status)
        VALUES(p_student, p_book_id, p_qty, 'Borrowed');
        RAISE NOTICE 'Borrowed % copies of book % for %', p_qty, p_book_id, p_student;
    ELSE
        RAISE NOTICE 'FAILED: Only % copies available, requested %', v_avail, p_qty;
    END IF;
END $$;

-- 5. CALL 2 valid + 1 exceeding
CALL borrow_book('2023001', 1, 2);
CALL borrow_book('2023002', 2, 1);
CALL borrow_book('2023003', 2, 5); -- exceeds

SELECT * FROM books;
SELECT * FROM book_loans;

-- 6. return_book PROCEDURE
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_status VARCHAR; v_book INT; v_qty INT;
BEGIN
    SELECT status, book_id, quantity INTO v_status, v_book, v_qty
    FROM book_loans WHERE loan_id = p_loan_id;
    
    IF v_status = 'Returned' THEN
        RAISE NOTICE 'Loan % already returned, no stock restored', p_loan_id;
    ELSE
        UPDATE book_loans SET status = 'Returned' WHERE loan_id = p_loan_id;
        UPDATE books SET available_copies = available_copies + v_qty WHERE book_id = v_book;
        RAISE NOTICE 'Loan % returned, % copies restored', p_loan_id, v_qty;
    END IF;
END $$;

CALL return_book(1);
CALL return_book(1); -- second call must not restore again

-- 7. Explicit Cursor - few copies
DO $$
DECLARE
    CURSOR low_books IS SELECT book_id, title, available_copies FROM books WHERE available_copies < 5;
    rec RECORD;
BEGIN
    RAISE NOTICE '--- Books with few copies ---';
    FOR rec IN low_books LOOP
        RAISE NOTICE 'Book % - % has % copies left', rec.book_id, rec.title, rec.available_copies;
    END LOOP;
END $$;

-- 8. EXCEPTION block - zero copies
DO $$
BEGIN
    CALL borrow_book('2023004', 1, 0);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'EXCEPTION CAUGHT: %', SQLERRM;
END $$;

-- 9. Final Queries
SELECT * FROM books;
SELECT * FROM book_loans;