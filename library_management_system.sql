-- Library Management System SQL Script
-- This script creates tables, constraints, triggers, and stored procedures for basic library operations.

CREATE DATABASE IF NOT EXISTS LibraryManagement;
USE LibraryManagement;

CREATE TABLE IF NOT EXISTS Categories (
  CategoryID INT AUTO_INCREMENT PRIMARY KEY,
  Name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS Authors (
  AuthorID INT AUTO_INCREMENT PRIMARY KEY,
  FirstName VARCHAR(50) NOT NULL,
  LastName VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS Books (
  BookID INT AUTO_INCREMENT PRIMARY KEY,
  Title VARCHAR(255) NOT NULL,
  CategoryID INT,
  TotalCopies INT NOT NULL DEFAULT 1,
  AvailableCopies INT NOT NULL DEFAULT 1,
  CONSTRAINT fk_books_category FOREIGN KEY (CategoryID)
    REFERENCES Categories(CategoryID)
      ON DELETE SET NULL
      ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS BookAuthors (
  BookID INT NOT NULL,
  AuthorID INT NOT NULL,
  PRIMARY KEY (BookID, AuthorID),
  CONSTRAINT fk_ba_book FOREIGN KEY (BookID)
    REFERENCES Books(BookID)
      ON DELETE CASCADE,
  CONSTRAINT fk_ba_author FOREIGN KEY (AuthorID)
    REFERENCES Authors(AuthorID)
      ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Members (
  MemberID INT AUTO_INCREMENT PRIMARY KEY,
  FirstName VARCHAR(50) NOT NULL,
  LastName VARCHAR(50) NOT NULL,
  Email VARCHAR(100) NOT NULL UNIQUE,
  Phone VARCHAR(20),
  JoinDate DATE NOT NULL DEFAULT (CURDATE())
);

CREATE TABLE IF NOT EXISTS Loans (
  LoanID INT AUTO_INCREMENT PRIMARY KEY,
  BookID INT NOT NULL,
  MemberID INT NOT NULL,
  IssueDate DATE NOT NULL DEFAULT (CURDATE()),
  DueDate DATE NOT NULL,
  ReturnDate DATE,
  CONSTRAINT fk_loans_book FOREIGN KEY (BookID)
    REFERENCES Books(BookID)
      ON DELETE CASCADE,
  CONSTRAINT fk_loans_member FOREIGN KEY (MemberID)
    REFERENCES Members(MemberID)
      ON DELETE CASCADE
);


DELIMITER $$
CREATE TRIGGER trg_after_issue
AFTER INSERT ON Loans
FOR EACH ROW
BEGIN
  UPDATE Books
    SET AvailableCopies = AvailableCopies - 1
    WHERE BookID = NEW.BookID;
END$$

CREATE TRIGGER trg_after_return
AFTER UPDATE ON Loans
FOR EACH ROW
BEGIN
  IF OLD.ReturnDate IS NULL AND NEW.ReturnDate IS NOT NULL THEN
    UPDATE Books
      SET AvailableCopies = AvailableCopies + 1
      WHERE BookID = NEW.BookID;
  END IF;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE AddBook(
  IN p_Title VARCHAR(255),
  IN p_CategoryID INT,
  IN p_TotalCopies INT,
  IN p_AuthorList TEXT 
)
BEGIN
  DECLARE last_book INT;
  INSERT INTO Books(Title, CategoryID, TotalCopies, AvailableCopies)
    VALUES(p_Title, p_CategoryID, p_TotalCopies, p_TotalCopies);
  SET last_book = LAST_INSERT_ID();

  WHILE CHAR_LENGTH(p_AuthorList) > 0 DO
    DECLARE aid INT;
    SET aid = CAST(SUBSTRING_INDEX(p_AuthorList, ',', 1) AS UNSIGNED);
    INSERT INTO BookAuthors(BookID, AuthorID) VALUES(last_book, aid);
    SET p_AuthorList = 
      TRIM(LEADING ',' FROM SUBSTRING(p_AuthorList, INSTR(p_AuthorList, ',')+1));
  END WHILE;
END$$

CREATE PROCEDURE RegisterMember(
  IN p_FirstName VARCHAR(50),
  IN p_LastName VARCHAR(50),
  IN p_Email VARCHAR(100),
  IN p_Phone VARCHAR(20)
)
BEGIN
  INSERT INTO Members(FirstName, LastName, Email, Phone)
    VALUES(p_FirstName, p_LastName, p_Email, p_Phone);
END$$

CREATE PROCEDURE IssueBook(
  IN p_BookID INT,
  IN p_MemberID INT,
  IN p_LoanDays INT
)
BEGIN
  DECLARE due DATE;
  SET due = DATE_ADD(CURDATE(), INTERVAL p_LoanDays DAY);
  INSERT INTO Loans(BookID, MemberID, DueDate)
    VALUES(p_BookID, p_MemberID, due);
END$$

CREATE PROCEDURE ReturnBook(
  IN p_LoanID INT
)
BEGIN
  UPDATE Loans
    SET ReturnDate = CURDATE()
    WHERE LoanID = p_LoanID
      AND ReturnDate IS NULL;
END$$

CREATE PROCEDURE SearchBooks(
  IN p_SearchText VARCHAR(255)
)
BEGIN
  SELECT b.BookID, b.Title, c.Name AS Category, b.AvailableCopies
  FROM Books b
  LEFT JOIN Categories c ON b.CategoryID = c.CategoryID
  LEFT JOIN BookAuthors ba ON b.BookID = ba.BookID
  LEFT JOIN Authors a ON ba.AuthorID = a.AuthorID
  WHERE b.Title LIKE CONCAT('%', p_SearchText, '%')
     OR a.FirstName LIKE CONCAT('%', p_SearchText, '%')
     OR a.LastName LIKE CONCAT('%', p_SearchText, '%')
  GROUP BY b.BookID;
END$$
DELIMITER ;

INSERT INTO Categories(Name) VALUES ('Science'),('Literature'),('History');
INSERT INTO Authors(FirstName, LastName) VALUES ('Jane','Austen'),('Albert','Einstein');
