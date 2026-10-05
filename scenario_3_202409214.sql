-- SCENARIO 3: University Cafeteria Meal Orders
DROP TABLE IF EXISTS meal_orders;
DROP TABLE IF EXISTS meals;

-- 1. CREATE TABLES
CREATE TABLE meals (
    meal_id SERIAL PRIMARY KEY,
    meal_name VARCHAR(100),
    available_servings INT
);

CREATE TABLE meal_orders (
    order_id SERIAL PRIMARY KEY,
    student_number VARCHAR(20),
    meal_id INT REFERENCES meals(meal_id),
    quantity INT,
    status VARCHAR(20) DEFAULT 'Ordered'
);

INSERT INTO meals (meal_name, available_servings) VALUES
('Chicken and Chips', 15),
('Beef Stew', 4),
('Vegetable Curry', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE v_avail INT;
BEGIN
    SELECT available_servings INTO v_avail FROM meals WHERE meal_id = 3;
    IF v_avail = 0 THEN
        RAISE NOTICE 'Meal ID 3 is UNAVAILABLE';
    ELSIF v_avail < 5 THEN
        RAISE NOTICE 'Meal ID 3 is LOW: % servings left', v_avail;
    ELSE
        RAISE NOTICE 'Meal ID 3 is AVAILABLE: % servings', v_avail;
    END IF;
END $$;

-- 3. WHILE and FOR loops
DO $$
DECLARE i INT := 1;
BEGIN
    RAISE NOTICE '--- WHILE: Order reminders ---';
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Kitchen order reminder %', i;
        i := i + 1;
    END LOOP;
    RAISE NOTICE '--- FOR: Counter checks ---';
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Checking counter %', i;
    END LOOP;
END $$;

-- 4. order_meal PROCEDURE
CREATE OR REPLACE PROCEDURE order_meal(p_student VARCHAR, p_meal_id INT, p_qty INT)
LANGUAGE plpgsql AS $$
DECLARE v_avail INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %', p_qty;
    END IF;
    SELECT available_servings INTO v_avail FROM meals WHERE meal_id = p_meal_id;
    IF v_avail IS NULL THEN
        RAISE NOTICE 'Meal % not found', p_meal_id;
    ELSIF v_avail >= p_qty THEN
        UPDATE meals SET available_servings = available_servings - p_qty WHERE meal_id = p_meal_id;
        INSERT INTO meal_orders(student_number, meal_id, quantity) VALUES(p_student, p_meal_id, p_qty);
        RAISE NOTICE 'Ordered % of meal % for %', p_qty, p_meal_id, p_student;
    ELSE
        RAISE NOTICE 'FAILED: Only % servings available, requested %', v_avail, p_qty;
    END IF;
END $$;

-- 5. CALL 2 valid + 1 exceeding
CALL order_meal('2023001', 1, 3);
CALL order_meal('2023002', 2, 2);
CALL order_meal('2023003', 2, 10); -- exceeds

SELECT * FROM meals;
SELECT * FROM meal_orders;

-- 6. cancel_order PROCEDURE
CREATE OR REPLACE PROCEDURE cancel_order(p_order_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_status VARCHAR; v_meal INT; v_qty INT;
BEGIN
    SELECT status, meal_id, quantity INTO v_status, v_meal, v_qty FROM meal_orders WHERE order_id = p_order_id;
    IF v_status = 'Cancelled' THEN
        RAISE NOTICE 'Order % already cancelled', p_order_id;
    ELSE
        UPDATE meal_orders SET status = 'Cancelled' WHERE order_id = p_order_id;
        UPDATE meals SET available_servings = available_servings + v_qty WHERE meal_id = v_meal;
        RAISE NOTICE 'Order % cancelled, % servings restored', p_order_id, v_qty;
    END IF;
END $$;

CALL cancel_order(1);
CALL cancel_order(1); -- second time no restore

-- 7. Explicit Cursor - low servings (Fixed for PG 18)
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT meal_id, meal_name, available_servings FROM meals WHERE available_servings < 5
    LOOP
        RAISE NOTICE 'Meal % - % has % servings left', rec.meal_id, rec.meal_name, rec.available_servings;
    END LOOP;
END $$;

-- 8. EXCEPTION block - zero qty
DO $$
BEGIN
    CALL order_meal('2023004', 1, 0);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'EXCEPTION CAUGHT: %', SQLERRM;
END $$;

-- 9. Final Queries
SELECT * FROM meals;
SELECT * FROM meal_orders;