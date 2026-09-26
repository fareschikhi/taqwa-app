-- Notifications written before `studentId` existed name their child only in
-- the body ("تم تسجيل غياب {name} اليوم", "{name}: ..."). Link each to the one
-- child of its recipient whose name it contains. Ambiguous or nameless rows,
-- such as the account-activation greeting, stay null and show for every child.
UPDATE `notifications` n
JOIN (
  SELECT n2.id, MIN(s.id) AS studentId
  FROM `notifications` n2
  JOIN `students` s ON TRUE
  JOIN `users` u ON u.id = s.userId
  LEFT JOIN `parents` pa ON pa.id = s.parentId
  WHERE n2.studentId IS NULL
    AND (pa.userId = n2.userId OR s.userId = n2.userId)
    AND INSTR(n2.body, u.fullName) > 0
  GROUP BY n2.id
  HAVING COUNT(*) = 1
) m ON m.id = n.id
SET n.studentId = m.studentId;
