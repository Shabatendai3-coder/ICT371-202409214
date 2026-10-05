-- SCENARIO 6: University Transport Booking
DROP TABLE IF EXISTS transport_bookings;
DROP TABLE IF EXISTS transport_routes;

-- 1. CREATE TABLES
CREATE TABLE transport_routes (
    route_id SERIAL PRIMARY KEY,
    route_name VARCHAR(100),
    available_seats INT
);

CREATE TABLE transport_bookings (
    booking_id SERIAL PRIMARY KEY,
    student_number VARCHAR(20),
    route_id INT REFERENCES transport_routes(route_id),
    seats_booked INT,
    status VARCHAR(20) DEFAULT 'Booked'
);

INSERT INTO transport_routes (route_name, available_seats) VALUES
('Kabwe - Campus', 20),
('Town - Campus', 3),
('Lusaka - Kabwe', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE v_seats INT;
BEGIN
    SELECT available_seats INTO v_seats FROM transport_routes WHERE route_id = 3;
    IF v_seats = 0 THEN
        RAISE NOTICE 'Route 3 is FULLY BOOKED';
    ELSIF v_seats < 5 THEN
        RAISE NOTICE 'Route 3 is ALMOST FULL: % seats left', v_seats;
    ELSE
        RAISE NOTICE 'Route 3 is AVAILABLE: % seats', v_seats;
    END IF;
END $$;

-- 3. WHILE and FOR loops
DO $$
DECLARE i INT := 1;
BEGIN
    RAISE NOTICE '--- WHILE: Departure alerts ---';
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Bus departure reminder %', i;
        i := i + 1;
    END LOOP;
    RAISE NOTICE '--- FOR: Seat checks ---';
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Checking bus %', i;
    END LOOP;
END $$;

-- 4. book_transport PROCEDURE
CREATE OR REPLACE PROCEDURE book_transport(p_student VARCHAR, p_route_id INT, p_qty INT)
LANGUAGE plpgsql AS $$
DECLARE v_avail INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid seat count: %', p_qty;
    END IF;
    SELECT available_seats INTO v_avail FROM transport_routes WHERE route_id = p_route_id;
    IF v_avail IS NULL THEN
        RAISE NOTICE 'Route % not found', p_route_id;
    ELSIF v_avail >= p_qty THEN
        UPDATE transport_routes SET available_seats = available_seats - p_qty WHERE route_id = p_route_id;
        INSERT INTO transport_bookings(student_number, route_id, seats_booked) VALUES(p_student, p_route_id, p_qty);
        RAISE NOTICE 'Booked % seat(s) on route % for %', p_qty, p_route_id, p_student;
    ELSE
        RAISE NOTICE 'FAILED: Only % seats available on route %, requested %', v_avail, p_route_id, p_qty;
    END IF;
END $$;

-- 5. CALL 2 valid + 1 exceeding
CALL book_transport('2023001', 1, 2);
CALL book_transport('2023002', 2, 2);
CALL book_transport('2023003', 2, 5); -- exceeds, only 1 left after previous

SELECT * FROM transport_routes;
SELECT * FROM transport_bookings;

-- 6. cancel_booking PROCEDURE
CREATE OR REPLACE PROCEDURE cancel_booking(p_booking_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_status VARCHAR; v_route INT; v_qty INT;
BEGIN
    SELECT status, route_id, seats_booked INTO v_status, v_route, v_qty FROM transport_bookings WHERE booking_id = p_booking_id;
    IF v_status = 'Cancelled' THEN
        RAISE NOTICE 'Booking % already cancelled, no seats restored', p_booking_id;
    ELSE
        UPDATE transport_bookings SET status = 'Cancelled' WHERE booking_id = p_booking_id;
        UPDATE transport_routes SET available_seats = available_seats + v_qty WHERE route_id = v_route;
        RAISE NOTICE 'Booking % cancelled, % seat(s) restored to route %', p_booking_id, v_qty, v_route;
    END IF;
END $$;

CALL cancel_booking(1);
CALL cancel_booking(1); -- second time no restore

-- 7. Explicit Cursor - low seats (FIXED, no error)
DO $$
DECLARE rec RECORD;
BEGIN
    RAISE NOTICE '--- Routes with few seats left ---';
    FOR rec IN SELECT route_id, route_name, available_seats FROM transport_routes WHERE available_seats < 5
    LOOP
        RAISE NOTICE 'Route % (%) has % seats left', rec.route_id, rec.route_name, rec.available_seats;
    END LOOP;
END $$;

-- 8. EXCEPTION block - zero seats
DO $$
BEGIN
    CALL book_transport('2023004', 1, 0);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'EXCEPTION CAUGHT: %', SQLERRM;
END $$;

-- 9. Final Queries
SELECT * FROM transport_routes;
SELECT * FROM transport_bookings;