-- ============================================================
-- TASK 3 dataset: Parent/Child Transaction Reconciliation practice set
-- ============================================================

DROP TABLE IF EXISTS financial_transaction_detail;
DROP TABLE IF EXISTS financial_transaction;

CREATE TABLE financial_transaction (
    transaction_id   INT PRIMARY KEY,
    admission_no     VARCHAR(20) NOT NULL,
    transaction_date DATE NOT NULL,
    total_amount     DECIMAL(12,2) NOT NULL,
    status           VARCHAR(20) NOT NULL
);

CREATE TABLE financial_transaction_detail (
    detail_id       INT PRIMARY KEY,
    transaction_id  INT NOT NULL,
    admission_no    VARCHAR(20) NOT NULL,
    fee_head        VARCHAR(50) NOT NULL,
    amount          DECIMAL(12,2) NOT NULL,
    status          VARCHAR(20) NOT NULL
);

-- ---------------- financial_transaction ----------------
INSERT INTO financial_transaction VALUES (1, 'ADM20001', '2025-07-21', 9000, 'Success');
INSERT INTO financial_transaction VALUES (2, 'ADM20002', '2025-06-19', 6000, 'Success');
INSERT INTO financial_transaction VALUES (3, 'ADM20002', '2025-01-03', 9000, 'Success');
INSERT INTO financial_transaction VALUES (4, 'ADM20003', '2025-04-21', 6000, 'Success');
INSERT INTO financial_transaction VALUES (5, 'ADM20003', '2025-07-02', 16000, 'Success');
INSERT INTO financial_transaction VALUES (6, 'ADM20004', '2025-02-19', 16000, 'Success');
INSERT INTO financial_transaction VALUES (7, 'ADM20005', '2025-04-12', 20000, 'Success');
INSERT INTO financial_transaction VALUES (8, 'ADM20005', '2025-02-19', 20000, 'Success');
INSERT INTO financial_transaction VALUES (9, 'ADM20006', '2025-09-14', 14000, 'Success');
INSERT INTO financial_transaction VALUES (10, 'ADM20007', '2025-04-03', 9000, 'Success');
INSERT INTO financial_transaction VALUES (11, 'ADM20008', '2025-05-20', 14000, 'Success');
INSERT INTO financial_transaction VALUES (12, 'ADM20008', '2025-07-06', 16000, 'Success');
INSERT INTO financial_transaction VALUES (13, 'ADM20009', '2025-09-19', 6000, 'Success');
INSERT INTO financial_transaction VALUES (14, 'ADM20009', '2025-08-03', 16000, 'Success');
INSERT INTO financial_transaction VALUES (15, 'ADM20010', '2025-02-02', 20000, 'Success');
INSERT INTO financial_transaction VALUES (16, 'ADM20011', '2025-06-01', 20000, 'Success');
INSERT INTO financial_transaction VALUES (17, 'ADM20012', '2025-04-13', 9000, 'Success');
INSERT INTO financial_transaction VALUES (18, 'ADM20013', '2025-09-09', 14000, 'Success');
INSERT INTO financial_transaction VALUES (19, 'ADM20014', '2025-04-01', 20000, 'Success');
INSERT INTO financial_transaction VALUES (20, 'ADM20015', '2025-10-19', 11000, 'Success');
INSERT INTO financial_transaction VALUES (21, 'ADM20015', '2025-09-13', 20000, 'Success');
INSERT INTO financial_transaction VALUES (22, 'ADM20016', '2025-04-15', 6000, 'Success');
INSERT INTO financial_transaction VALUES (23, 'ADM20017', '2025-10-05', 6000, 'Success');
INSERT INTO financial_transaction VALUES (24, 'ADM20018', '2025-02-28', 6000, 'Success');
INSERT INTO financial_transaction VALUES (25, 'ADM20018', '2025-06-20', 11000, 'Success');
INSERT INTO financial_transaction VALUES (26, 'ADM20019', '2025-08-16', 14000, 'Success');
INSERT INTO financial_transaction VALUES (27, 'ADM20020', '2025-05-16', 20000, 'Success');
INSERT INTO financial_transaction VALUES (28, 'ADM20021', '2025-03-23', 11000, 'Success');
INSERT INTO financial_transaction VALUES (29, 'ADM20021', '2025-02-23', 11000, 'Success');
INSERT INTO financial_transaction VALUES (30, 'ADM20022', '2025-09-18', 9000, 'Success');
INSERT INTO financial_transaction VALUES (31, 'ADM20023', '2025-04-07', 20000, 'Success');
INSERT INTO financial_transaction VALUES (32, 'ADM20024', '2025-10-12', 20000, 'Success');
INSERT INTO financial_transaction VALUES (33, 'ADM20025', '2025-04-16', 11000, 'Success');
INSERT INTO financial_transaction VALUES (34, 'ADM20026', '2025-02-27', 11000, 'Success');
INSERT INTO financial_transaction VALUES (35, 'ADM20026', '2025-04-16', 20000, 'Success');
INSERT INTO financial_transaction VALUES (36, 'ADM20027', '2025-08-13', 14000, 'Success');
INSERT INTO financial_transaction VALUES (37, 'ADM20027', '2025-03-01', 9000, 'Success');
INSERT INTO financial_transaction VALUES (38, 'ADM20028', '2025-10-16', 16000, 'Success');
INSERT INTO financial_transaction VALUES (39, 'ADM20029', '2025-02-17', 20000, 'Success');
INSERT INTO financial_transaction VALUES (40, 'ADM20029', '2025-01-09', 9000, 'Success');
INSERT INTO financial_transaction VALUES (41, 'ADM20030', '2025-09-14', 11000, 'Success');

-- ---------------- financial_transaction_detail ----------------
INSERT INTO financial_transaction_detail VALUES (1, 1, 'ADM20001', 'Tuition Fee', 9000, 'Success');
INSERT INTO financial_transaction_detail VALUES (2, 2, 'ADM20002', 'Development Fee', 6000, 'Success');
INSERT INTO financial_transaction_detail VALUES (3, 3, 'ADM20002', 'Hostel Fee', 2945, 'Success');
INSERT INTO financial_transaction_detail VALUES (4, 3, 'ADM20002', 'Tuition Fee', 2588, 'Success');
INSERT INTO financial_transaction_detail VALUES (5, 3, 'ADM20002', 'Development Fee', 3467, 'Success');
INSERT INTO financial_transaction_detail VALUES (6, 4, 'ADM20003', 'Development Fee', 6000, 'Success');
INSERT INTO financial_transaction_detail VALUES (7, 5, 'ADM20003', 'Tuition Fee', 6190, 'Success');
INSERT INTO financial_transaction_detail VALUES (8, 5, 'ADM20003', 'Exam Fee', 9810, 'Success');
INSERT INTO financial_transaction_detail VALUES (9, 6, 'ADM20004', 'Development Fee', 5295, 'Success');
INSERT INTO financial_transaction_detail VALUES (10, 6, 'ADM20004', 'Exam Fee', 10705, 'Success');
INSERT INTO financial_transaction_detail VALUES (12, 8, 'ADM20005', 'Development Fee', 20000, 'Success');
INSERT INTO financial_transaction_detail VALUES (13, 9, 'ADM20006', 'Hostel Fee', 5719, 'Success');
INSERT INTO financial_transaction_detail VALUES (14, 9, 'ADM20006', 'Development Fee', 4929, 'Success');
INSERT INTO financial_transaction_detail VALUES (15, 10, 'ADM20007', 'Development Fee', 5063, 'Success');
INSERT INTO financial_transaction_detail VALUES (16, 10, 'ADM20007', 'Hostel Fee', 3937, 'Success');
INSERT INTO financial_transaction_detail VALUES (17, 11, 'ADM20008', 'Tuition Fee', 14000, 'Success');
INSERT INTO financial_transaction_detail VALUES (18, 12, 'ADM20008', 'Exam Fee', 6824, 'Success');
INSERT INTO financial_transaction_detail VALUES (19, 12, 'ADM20008', 'Hostel Fee', 9176, 'Success');
INSERT INTO financial_transaction_detail VALUES (20, 13, 'ADM20009', 'Library Fee', 2870, 'Success');
INSERT INTO financial_transaction_detail VALUES (21, 13, 'ADM20009', 'Development Fee', 3130, 'Success');
INSERT INTO financial_transaction_detail VALUES (22, 14, 'ADM20009', 'Library Fee', 16000, 'Success');
INSERT INTO financial_transaction_detail VALUES (23, 15, 'ADM20010', 'Development Fee', 7708, 'Success');
INSERT INTO financial_transaction_detail VALUES (24, 15, 'ADM20010', 'Hostel Fee', 12292, 'Success');
INSERT INTO financial_transaction_detail VALUES (25, 16, 'ADM20011', 'Library Fee', 6703, 'Success');
INSERT INTO financial_transaction_detail VALUES (26, 16, 'ADM20011', 'Exam Fee', 4224, 'Success');
INSERT INTO financial_transaction_detail VALUES (27, 16, 'ADM20011', 'Development Fee', 9073, 'Success');
INSERT INTO financial_transaction_detail VALUES (28, 17, 'ADM20012', 'Hostel Fee', 3913, 'Success');
INSERT INTO financial_transaction_detail VALUES (29, 17, 'ADM20012', 'Tuition Fee', 2365, 'Success');
INSERT INTO financial_transaction_detail VALUES (30, 17, 'ADM20012', 'Development Fee', 2722, 'Success');
INSERT INTO financial_transaction_detail VALUES (31, 18, 'ADM20013', 'Library Fee', 4834, 'Success');
INSERT INTO financial_transaction_detail VALUES (32, 18, 'ADM20013', 'Hostel Fee', 3234, 'Success');
INSERT INTO financial_transaction_detail VALUES (33, 18, 'ADM20013', 'Tuition Fee', 5932, 'Success');
INSERT INTO financial_transaction_detail VALUES (34, 19, 'ADM20014', 'Development Fee', 7692, 'Success');
INSERT INTO financial_transaction_detail VALUES (35, 19, 'ADM20014', 'Exam Fee', 4230, 'Success');
INSERT INTO financial_transaction_detail VALUES (36, 19, 'ADM20014', 'Hostel Fee', 8078, 'Success');
INSERT INTO financial_transaction_detail VALUES (37, 20, 'ADM20015', 'Exam Fee', 4807, 'Success');
INSERT INTO financial_transaction_detail VALUES (38, 20, 'ADM20015', 'Tuition Fee', 6193, 'Success');
INSERT INTO financial_transaction_detail VALUES (39, 21, 'ADM20015', 'Hostel Fee', 8889, 'Success');
INSERT INTO financial_transaction_detail VALUES (40, 21, 'ADM20015', 'Development Fee', 4668, 'Success');
INSERT INTO financial_transaction_detail VALUES (41, 21, 'ADM20015', 'Tuition Fee', 6443, 'Success');
INSERT INTO financial_transaction_detail VALUES (44, 23, 'ADM20017', 'Library Fee', 6000, 'Success');
INSERT INTO financial_transaction_detail VALUES (45, 24, 'ADM20018', 'Development Fee', 2067, 'Success');
INSERT INTO financial_transaction_detail VALUES (46, 24, 'ADM20018', 'Hostel Fee', 3933, 'Success');
INSERT INTO financial_transaction_detail VALUES (47, 25, 'ADM20018', 'Hostel Fee', 3681, 'Success');
INSERT INTO financial_transaction_detail VALUES (48, 25, 'ADM20018', 'Tuition Fee', 7319, 'Success');
INSERT INTO financial_transaction_detail VALUES (49, 26, 'ADM20019', 'Tuition Fee', 4629, 'Success');
INSERT INTO financial_transaction_detail VALUES (50, 26, 'ADM20019', 'Exam Fee', 9371, 'Success');
INSERT INTO financial_transaction_detail VALUES (51, 27, 'ADM20020', 'Development Fee', 4323, 'Success');
INSERT INTO financial_transaction_detail VALUES (52, 27, 'ADM20020', 'Tuition Fee', 12769, 'Success');
INSERT INTO financial_transaction_detail VALUES (53, 28, 'ADM20021', 'Development Fee', 11000, 'Success');
INSERT INTO financial_transaction_detail VALUES (54, 29, 'ADM20021', 'Development Fee', 6297, 'Success');
INSERT INTO financial_transaction_detail VALUES (55, 29, 'ADM20021', 'Library Fee', 4703, 'Success');
INSERT INTO financial_transaction_detail VALUES (56, 30, 'ADM20022', 'Exam Fee', 4876, 'Success');
INSERT INTO financial_transaction_detail VALUES (57, 30, 'ADM20022', 'Development Fee', 4124, 'Success');
INSERT INTO financial_transaction_detail VALUES (58, 31, 'ADM20023', 'Library Fee', 10741, 'Success');
INSERT INTO financial_transaction_detail VALUES (59, 31, 'ADM20023', 'Tuition Fee', 4089, 'Success');
INSERT INTO financial_transaction_detail VALUES (60, 31, 'ADM20023', 'Hostel Fee', 5170, 'Success');
INSERT INTO financial_transaction_detail VALUES (61, 32, 'ADM20024', 'Library Fee', 7323, 'Success');
INSERT INTO financial_transaction_detail VALUES (62, 32, 'ADM20024', 'Development Fee', 4666, 'Success');
INSERT INTO financial_transaction_detail VALUES (63, 32, 'ADM20024', 'Tuition Fee', 8011, 'Success');
INSERT INTO financial_transaction_detail VALUES (64, 33, 'ADM20025', 'Hostel Fee', 7776, 'Success');
INSERT INTO financial_transaction_detail VALUES (65, 34, 'ADM20026', 'Hostel Fee', 5850, 'Success');
INSERT INTO financial_transaction_detail VALUES (66, 35, 'ADM20026', 'Hostel Fee', 3983, 'Success');
INSERT INTO financial_transaction_detail VALUES (67, 35, 'ADM20026', 'Library Fee', 13480, 'Success');
INSERT INTO financial_transaction_detail VALUES (69, 37, 'ADM20027', 'Development Fee', 4878, 'Success');
INSERT INTO financial_transaction_detail VALUES (70, 37, 'ADM20027', 'Hostel Fee', 4122, 'Success');
INSERT INTO financial_transaction_detail VALUES (71, 38, 'ADM20028', 'Exam Fee', 3036, 'Success');
INSERT INTO financial_transaction_detail VALUES (72, 38, 'ADM20028', 'Development Fee', 11097, 'Success');
INSERT INTO financial_transaction_detail VALUES (73, 39, 'ADM20029', 'Hostel Fee', 10957, 'Success');
INSERT INTO financial_transaction_detail VALUES (74, 39, 'ADM20029', 'Exam Fee', 9043, 'Success');
INSERT INTO financial_transaction_detail VALUES (77, 41, 'ADM20030', 'Tuition Fee', 6262, 'Success');
INSERT INTO financial_transaction_detail VALUES (78, 41, 'ADM20030', 'Library Fee', 4738, 'Success');
INSERT INTO financial_transaction_detail VALUES (79, 141, 'ADM20029', 'Development Fee', 2000, 'Success');
INSERT INTO financial_transaction_detail VALUES (80, 142, 'ADM20008', 'Exam Fee', 3500, 'Success');
INSERT INTO financial_transaction_detail VALUES (81, 143, 'ADM20002', 'Tuition Fee', 4000, 'Success');
INSERT INTO financial_transaction_detail VALUES (82, 144, 'ADM20015', 'Development Fee', 2000, 'Success');