
import subprocess  # noqa: S404
from unittest.mock import MagicMock, patch
from django.contrib.gis.db.models.functions import Distance

from django.test import TestCase
from users.models import Profile
from users.views import profile_viewing


class TestProfileViews(TestCase):
    """Test Profile"""

    @classmethod
    def setUpTestData(cls) -> None:
        # Install profile examples
        stdin = 'y\n'
        if not Profile.objects.exists():
            subprocess.run(['python', 'manage.py', 'install_fixtures'], stdout=subprocess.PIPE, text=True, check=False)  # noqa: S603, S607
            subprocess.run(['python', 'manage.py', 'install_profile_examples'], stdout=subprocess.PIPE, input=stdin, text=True, check=False)  # noqa: S603, S607
        if Profile.objects.count() < profile_viewing.ProfilesView.PROFILES_PER_PAGE:
            subprocess.run(['python', 'manage.py', 'create_more_new_profiles.py'], stdout=subprocess.PIPE, check=False)  # noqa: S603, S607

    def setUp(self):
        pass

    @patch('users.views.profile_viewing.Profile.get_online_profiles_ids')
    def test_get_profiles_sorting_with_filter_mixed(self, mock_get_online_profiles_ids: MagicMock):  # noqa: PLR0914
        """
        Test the order and filtering of profiles, including valid values and next page detection

        Consider the following behaviors:

        - The order of profiles should follow the preset order in get_profiles_display_group_settings
        - The filtering of profiles should adhere to the filters in get_profiles_display_group_settings
        - The profile list should contain only Profile instances, excluding None
        - The has_more_profiles should be True as there are more profiles to display in this test
        - The next_page should be an integer as there are more profiles to display in this test
        """
        # Mock for testing online profiles
        mock_get_online_profiles_ids.return_value = [103, 90, 125, 71, 100]

        # Mock the fill_profiles_list_with_remaining_matches method to capture the profiles added in the function
        orignal_fill_profiles_list_with_remaining_matches = profile_viewing.ProfilesView.fill_profiles_list_with_remaining_matches

        def mock_fill_profiles_list_with_remaining_matches(_, matches, displayed_profiles_ids_to_exclude, profiles_list):  # noqa: ANN001
            original_profiles_list = profiles_list.copy()

            orignal_fill_profiles_list_with_remaining_matches(matches, displayed_profiles_ids_to_exclude, profiles_list)

            added_profiles_in_func = set(profiles_list) - set(original_profiles_list)
            profiles_list.append(added_profiles_in_func)

        # Test setup
        request = MagicMock()
        request.session = self.client.session
        profiles_view = profile_viewing.ProfilesView()

        # Test execution

        matches = Profile.matches.find_matches_for_profile(profile=self.profile, is_guest_user=False).annotate(
            distance=Distance('location', self.profile.location)
        ).order_by('distance')

        matches_length = matches.count()

        page = 1
        has_more_profiles = True
        displayed_profiles_ids_to_exclude = []  # Profiles already displayed (displayed_profiles_ids_to_exclude en view)
        profiles_list_displayed = set()  # Profiles displayed from profiles_list
        offset = profiles_view.PROFILES_PER_PAGE // profiles_view.PROFILES_GROUP_PAGINATION_SIZE
        profiles_added_in_fill_function = set()  # Profiles added in the fill_profiles_list_with_remaining_matches function

        while has_more_profiles:
            local_profiles_list_length = min(profiles_view.PROFILES_PER_PAGE, matches_length - len(displayed_profiles_ids_to_exclude))

            # Patch the fill_profiles_list_with_remaining_matches method to capture the profiles added in the function
            with patch.object(profile_viewing.ProfilesView,
                              'fill_profiles_list_with_remaining_matches',
                              new=mock_fill_profiles_list_with_remaining_matches):

                profiles_list, has_more_profiles, page = profiles_view.get_profiles_sorting_with_filter_mixed(
                    request, matches, page
                )

            # If the last element is a set, it means the fill_profiles_list_with_remaining_matches function was called
            if isinstance(profiles_list[-1], set):
                profiles_added_in_fill_function = profiles_list.pop()

            # Verify each group's positions contain correct profiles
            for profiles_display_group_key, group_settings in (profiles_view.get_profiles_display_group_settings(matches)).items():

                filters = group_settings['filters']
                order_by_fields = group_settings['order_by_fields']
                positions = sorted(group_settings['positions'])

                profiles_queryset = (
                     matches
                    .filter(**filters)
                    .exclude(id__in=displayed_profiles_ids_to_exclude)
                    .order_by(*order_by_fields)
                    .distinct()
                )

                current_profiles_filtered = list(profiles_queryset)
                if not current_profiles_filtered:
                    continue

                total_positions_out_of_range = len(
                    [
                        position for position in positions
                        if position >=
                        local_profiles_list_length
                    ]
                )

                total_positions_to_extract = min(
                    len(positions) - total_positions_out_of_range,
                    len(current_profiles_filtered)
                )

                positions = positions[:total_positions_to_extract]
                current_profiles_filtered = current_profiles_filtered[:total_positions_to_extract]
                current_profiles_ids_selected = [profile.id for profile in current_profiles_filtered]

                # Include the profiles added in the fill_profiles_list_with_remaining_matches function, the same behavior as the view
                displayed_profiles_ids_to_exclude.extend(current_profiles_ids_selected + [profile.id for profile in profiles_added_in_fill_function])

                for offset_range in range(offset):
                    for position, filtered_profile in zip(
                        positions,
                        current_profiles_filtered,
                        strict=True
                    ):

                        # Print debug information to compare with the visual content in the browser and verify the order.
                        # Profiles online should be in the positions: [7, 57] and [3, 15, 17] according to the get_profiles_display_group_settings function.
                        # If you change the initial online IDs, another filter may capture them first. Check if this occurs.

                        # print("\n--------------------------------------------\n")
                        # print(f"profile_list[{position}]: {profiles_list[position]}")
                        # print(f"Popularity: {profiles_list[position].popularity}")
                        # print(f"Online: {profiles_list[position].is_online}")
                        # print(f"Distance: {profiles_list[position].distance}")
                        # print(f"Is new: {profiles_list[position].is_new}")
                        # print(f"Has photo: {profiles_list[position].profile_photo is not None}")
                        # print(f"Group: {profiles_display_group_key}")

                        final_position = position + offset_range * profiles_view.PROFILES_GROUP_PAGINATION_SIZE

                        # Ensure the profile is in the correct filter group
                        # Include the profiles added in the fill_profiles_list_with_remaining_matches function
                        self.assertIn(
                            profiles_list[final_position],
                            set(current_profiles_filtered).union(profiles_added_in_fill_function),
                            f"Profile at position {final_position} should belong to group {profiles_display_group_key}"
                        )

                        # Ensure the profile is in the correct position
                        self.assertEqual(
                            profiles_list[final_position],
                            filtered_profile,
                            f"Profile at position {final_position} should be the same as the filtered profiles in group {profiles_display_group_key}"
                        )

                        # Ensure the profile is not duplicated
                        self.assertNotIn(
                                profiles_list[final_position].id,
                                profiles_list_displayed,
                                f"Profile at position {final_position} should not be in the excluded profiles list"
                        )

                    profiles_added_in_fill_function = set()
                profiles_list_displayed.update(profiles_list)

            # Ensure that there are no None values in the profiles list
            self.assertNotIn(None, profiles_list)

        # Ensure that all profiles are displayed in view
        self.assertEqual(len(profiles_list_displayed), matches_length)

        # Ensure that all profiles are displayed in test
        self.assertEqual(len(displayed_profiles_ids_to_exclude), matches_length)

        # Ensure that function returns the correct values
        self.assertEqual(has_more_profiles, False)
        self.assertIsInstance(page, int)

    def test_fill_profiles_list_with_remaining_matches(self):
        """
        Test the fill_profiles_list_with_remaining_matches method

        Consider the following behaviors:

        - The method should fill the profiles_list with the remaining matches
        - The method should not return any None profiles
        - The method should not add any profiles already in the profiles_list
        """

        profiles_list = [None] * profile_viewing.ProfilesView.PROFILES_PER_PAGE
        profiles_to_insert = [103, 90, 125, 71, 100]

        # Test setup
        profiles_view = profile_viewing.ProfilesView()
        profiles = [Profile.objects.get(id=profile_id) for profile_id in profiles_to_insert]

        for i, profile in enumerate(profiles):
            profiles_list[i * 2] = profile

        displayed_profiles_ids_to_exclude = [profile.id for profile in profiles_list if profile is not None]

        # Test execution
        profiles_view.fill_profiles_list_with_remaining_matches(
            matches=Profile.objects.exclude(id__in=displayed_profiles_ids_to_exclude),
            displayed_profiles_ids_to_exclude=displayed_profiles_ids_to_exclude,  # type:ignore
            profiles_list=profiles_list
        )

        if not profiles_list:
            self.fail("No profiles were added to the profiles list")
            return

        # Ensure the profiles_list is filled with the remaining matches
        self.assertEqual(len(profiles_list), profile_viewing.ProfilesView.PROFILES_PER_PAGE)

        # Ensure the profiles_list does not contain any duplicate profiles
        self.assertEqual(len(profiles_list), len(set(profiles_list)))

        # Ensure the profiles_list does not contain any None profiles
        self.assertNotIn(None, profiles_list)
