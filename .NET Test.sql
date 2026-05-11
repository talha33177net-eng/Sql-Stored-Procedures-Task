--Question 1: Write a stored procedure named usp_GetEmployeeActivityLog, proposed to retrieve employee activity records. 
--The procedure must accommodate optional filtering parameters, specifically: Employee ID, a defined date range, and a maximum row limit for the result set.

GO
CREATE PROCEDURE usp_GetEmployeeActivityLog
    @EmployeeId  BIGINT    = NULL,
    @StartDate   DATETIME2 = NULL,
    @EndDate     DATETIME2 = NULL,
    @MaxRows     INT       = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(YEAR, -1, @EndDate);

    SELECT TOP (@MaxRows)
        al.Id,
        al.ActivityType,
        al.Action,
        al.Description,
        al.UpdatedOn,
        al.IP,
        al.Impersonated,
        e.FirstName + ' ' + ISNULL(e.LastName, '') AS EmployeeName,
        e.Email
    FROM Main.ActivityLog al
    INNER JOIN Main.Employee e ON al.UpdatedBy = e.Id
    WHERE
        (@EmployeeId IS NULL OR al.UpdatedBy = @EmployeeId)
        AND al.UpdatedOn >= @StartDate
        AND al.UpdatedOn <= @EndDate
    ORDER BY al.UpdatedOn DESC;

END;
GO

-- Test with defaults 
EXEC usp_GetEmployeeActivityLog;
-- Test row limit
EXEC usp_GetEmployeeActivityLog @MaxRows = 5;
-- Test with specific employee
EXEC usp_GetEmployeeActivityLog @EmployeeId = 1;




--Question 2: Write a stored procedure named usp_GetEmployeeSummary that furnishes employee statistical data, including the total number of employees, 
--active employees, and archived employees, with optional filtering capability by account.

GO
CREATE PROCEDURE usp_GetEmployeeSummary
    @AccountId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        COUNT(*) AS TotalEmployees,
        SUM(CASE WHEN Archived = 0 THEN 1 ELSE 0 END) AS ActiveEmployees,
        SUM(CASE WHEN Archived = 1 THEN 1 ELSE 0 END) AS ArchivedEmployees
    FROM Main.Employee
    WHERE @AccountId IS NULL OR AccountId = @AccountId;

END;
GO

-- Test with defaults 
EXEC usp_GetEmployeeSummary;
-- Test with specific AccountId
EXEC usp_GetEmployeeSummary @AccountId = 1;




--Question 3: Write a stored procedure named usp_GetActivityReport that generates a report detailing activity counts stratified 
--by type and action within a specified date range, with aggregation performed by activity type.
Go
CREATE PROCEDURE usp_GetActivityReport
    @StartDate DATETIME2 = NULL,
    @EndDate   DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(YEAR, -1, @EndDate);

    SELECT 
        ActivityType,
        Action,
        COUNT(*) AS ActivityCount
    FROM Main.ActivityLog
    WHERE UpdatedOn >= @StartDate
        AND UpdatedOn <= @EndDate
    GROUP BY ActivityType, Action
    ORDER BY ActivityCount DESC;

END;
GO

-- Test 1: defaults
EXEC usp_GetActivityReport;

-- Test 2: custom range
EXEC usp_GetActivityReport @StartDate = '2020-01-01', @EndDate = '2030-01-01';





--Question 4: Write a stored procedure named usp_SearchContacts designed to facilitate the search for contacts based on name or email address, 
--incorporating support for pagination. The procedure should return both the search results and the total count of matching records.
Go
CREATE PROCEDURE usp_SearchContacts
    @SearchTerm NVARCHAR(255) = NULL,
    @PageNumber INT = 1,
    @PageSize   INT = 25
AS
BEGIN
    SET NOCOUNT ON;

    -- Total count
    SELECT COUNT(*) AS TotalRecords
    FROM Main.Contact
    WHERE @SearchTerm IS NULL
        OR Name LIKE '%' + @SearchTerm + '%'
        OR Email LIKE '%' + @SearchTerm + '%';

    -- Paginated results
    SELECT Id, Name, Email, Phone
    FROM Main.Contact
    WHERE @SearchTerm IS NULL
        OR Name LIKE '%' + @SearchTerm + '%'
        OR Email LIKE '%' + @SearchTerm + '%'
    ORDER BY Name
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

END;
GO

-- Test 1: no search term, first page
EXEC usp_SearchContacts;
-- Test 2: search by name
EXEC usp_SearchContacts @SearchTerm = 'john';
-- Test 3: second page
EXEC usp_SearchContacts @SearchTerm = 'john', @PageNumber = 2;




--Question 5: Write a stored procedure named usp_GetWorkflowParticipants that retrieves the participants associated with 
--a given workflow, including their corresponding employee details, and orders the output according to the participant order.
GO
CREATE PROCEDURE usp_GetWorkflowParticipants
    @WorkflowId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.Id AS ParticipantId,
        p.Name AS ParticipantName,
        p.WorkflowId,
        p.[Order] AS ParticipantOrder,
        p.WorkflowType,
        p.Archived,
        e.Id AS EmployeeId,
        e.FirstName + ' ' + ISNULL(e.LastName, '') AS EmployeeName,
        e.Email,
        e.Title
    FROM Workflow.Participant p
    INNER JOIN Main.Employee e ON p.UserId = e.Id
    WHERE p.WorkflowId = @WorkflowId
    ORDER BY p.[Order];

END;
GO

-- Test with a workflow that exists
EXEC usp_GetWorkflowParticipants @WorkflowId = 1;




--Question 6: Write a stored procedure named usp_GetEmployeeLoginHistory that returns the most recent login dates for employees, 
--offering options to filter the results by a date range and to restrict the output to only those employees who have not logged in recently.
GO
CREATE PROCEDURE usp_GetEmployeeLoginHistory
    @DaysSinceLastLogin INT = NULL,
    @StartDate DATETIME2 = NULL,
    @EndDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(MONTH, -6, @EndDate);

    SELECT 
        e.Id,
        e.EmployeeId,
        e.FirstName + ' ' + ISNULL(e.LastName, '') AS EmployeeName,
        e.Email,
        e.LastLogin,
        CASE 
            WHEN e.LastLogin IS NULL THEN NULL
            ELSE DATEDIFF(DAY, e.LastLogin, GETDATE())
        END AS DaysSinceLastLogin,
        e.Status,
        e.Archived
    FROM Main.Employee e
    WHERE 
        e.Archived = 0
        AND (
            (@DaysSinceLastLogin IS NULL)
            OR (e.LastLogin IS NOT NULL AND DATEDIFF(DAY, e.LastLogin, GETDATE()) >= @DaysSinceLastLogin)
            OR (e.LastLogin IS NULL AND @DaysSinceLastLogin IS NOT NULL)
        )
        AND (
            (e.LastLogin IS NULL)
            OR (e.LastLogin BETWEEN @StartDate AND @EndDate)
        )
    ORDER BY 
        CASE WHEN e.LastLogin IS NULL THEN 1 ELSE 0 END,
        e.LastLogin DESC;

END;
GO

-- Test
EXEC usp_GetEmployeeLoginHistory;
EXEC usp_GetEmployeeLoginHistory @DaysSinceLastLogin = 30;





--Question 7: Write a stored procedure named usp_GenerateActivityDashboard that compiles a comprehensive dashboard showcasing 
--activity metrics per employee, encompassing activity counts, the timestamp of the last activity, and the distribution of activity types.
GO

CREATE PROCEDURE usp_GenerateActivityDashboard
    @StartDate DATETIME2 = NULL,
    @EndDate DATETIME2 = NULL,
    @TopEmployees INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(YEAR, -1, @EndDate);  -- Changed from MONTH to YEAR

    -- Result Set 1: Top active employees
    SELECT TOP (@TopEmployees)
        e.Id AS EmployeeId,
        e.FirstName + ' ' + ISNULL(e.LastName, '') AS EmployeeName,
        e.Email,
        e.Title,
        COUNT(al.Id) AS TotalActivities,
        MAX(al.UpdatedOn) AS LastActivity,
        COUNT(DISTINCT al.ActivityType) AS UniqueActivityTypes
    FROM Main.Employee e
    INNER JOIN Main.ActivityLog al ON e.Id = al.UpdatedBy
    WHERE al.UpdatedOn BETWEEN @StartDate AND @EndDate
        AND e.Archived = 0
    GROUP BY e.Id, e.FirstName, e.LastName, e.Email, e.Title
    ORDER BY TotalActivities DESC;

    -- Result Set 2: Activity type breakdown
    SELECT 
        al.ActivityType,
        al.Action,
        COUNT(*) AS Count
    FROM Main.ActivityLog al
    WHERE al.UpdatedOn BETWEEN @StartDate AND @EndDate
    GROUP BY al.ActivityType, al.Action
    ORDER BY Count DESC;

END;
GO

-- Test
EXEC usp_GenerateActivityDashboard;
EXEC usp_GenerateActivityDashboard @TopEmployees = 5;