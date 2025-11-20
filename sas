1
1 

CREATE FUNCTION dbo.GetVisitorMinutes
(
    @VisitorId INT
)
RETURNS INT
AS
BEGIN
    DECLARE @minutes INT;

    SELECT @minutes = ISNULL(SUM(dur), 0)
    FROM
    (
        SELECT DISTINCT t.SessionId, f.Duration AS dur
        FROM dbo.Ticket t
        JOIN dbo.[Session] s ON t.SessionId = s.SessionId
        JOIN dbo.Film f ON s.FilmId = f.FilmId
        WHERE t.VisitorId = @VisitorId
    ) AS x;

    RETURN @minutes;
END
GO

Пример использования (вывести для всех посетителей):

SELECT v.VisitorId, v.Phone, dbo.GetVisitorMinutes(v.VisitorId) AS Minutes
FROM dbo.Visitor v;


2 

CREATE FUNCTION dbo.GetFilmsByGenre
(
    @GenreName NVARCHAR(50)
)
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT
        f.FilmId,
        f.Title,
        Genres = (
            SELECT STRING_AGG(g.GenreName, ', ')
            FROM dbo.FilmGenre fg
            JOIN dbo.Genre g ON fg.GenreId = g.GenreId
            WHERE fg.FilmId = f.FilmId
        )
    FROM dbo.Film f
    JOIN dbo.FilmGenre fg2 ON f.FilmId = fg2.FilmId
    JOIN dbo.Genre g2 ON fg2.GenreId = g2.GenreId
    WHERE g2.GenreName = @GenreName
);
GO

Пример:

SELECT * FROM dbo.GetFilmsByGenre(N'Драма');


3 

CREATE PROCEDURE dbo.AddTicket
    @Phone NVARCHAR(20),
    @SessionId INT,
    @Row TINYINT,
    @Seat TINYINT,
    @TicketId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @VisitorId INT;

        SELECT @VisitorId = VisitorId FROM dbo.Visitor WHERE Phone = @Phone;

        IF @VisitorId IS NULL
        BEGIN
            INSERT INTO dbo.Visitor(Phone) VALUES(@Phone);
            SET @VisitorId = SCOPE_IDENTITY();
        END

        -- проверка занятости места
        IF EXISTS (SELECT 1 FROM dbo.Ticket WHERE SessionId = @SessionId AND [Row] = @Row AND Seat = @Seat)
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Место уже занято для данного сеанса.', 16, 1);
            RETURN;
        END

        INSERT INTO dbo.Ticket (SessionId, VisitorId, [Row], Seat)
        VALUES (@SessionId, @VisitorId, @Row, @Seat);

        SET @TicketId = SCOPE_IDENTITY();

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
        RETURN;
    END CATCH
END
GO


DECLARE @NewTicketId INT;
EXEC dbo.AddTicket @Phone = N'7999123456', @SessionId = 1, @Row = 5, @Seat = 7, @TicketId = @NewTicketId OUTPUT;
SELECT @NewTicketId AS NewTicketId;


5 

CREATE FUNCTION dbo.GetTodayFilmsByCinema
(
    @CinemaName NVARCHAR(50)
)
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT
        f.FilmId,
        f.Title,
        StartTime = FORMAT(s.StartDate, 'HH:mm'),
        HallNumber = h.HallNumber
    FROM dbo.[Session] s
    JOIN dbo.Film f ON s.FilmId = f.FilmId
    JOIN dbo.Hall h ON s.HallId = h.HallId
    WHERE h.Cinema = @CinemaName
      AND CAST(s.StartDate AS date) = CAST(GETDATE() AS date)
    ORDER BY s.StartDate
);
GO



SELECT * FROM dbo.GetTodayFilmsByCinema(N'Макси');

